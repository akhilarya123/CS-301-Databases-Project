CREATE TABLE course_catalogue(
    course_id varchar(6) primary key, 
    lecture real not null,
    tutorial real not null,
    practical real not null,
    selfstudy real not null,
    credits real not null
);

CREATE TABLE course_offerings(
    course_id varchar(6) not null,
    semester int not null,
    yr int not null,
    teacher_id varchar(12) not null,
    section_id int not null,
    cgpa_criteria real,
    PRIMARY KEY(course_id, teacher_id, section_id)
);

CREATE TABLE prerequisite(
    course_id varchar(6) not null,
    prereq varchar(6) not null,
    primary key(course_id, prereq)
);

CREATE TABLE batch_req(
    course_id varchar(6) not null,
    department varchar(3) not null,
    yr integer not null,
    primary key(course_id, department, yr)
);

CREATE TABLE time_table(
    course_id varchar(6) not null,
    day_of_week int not null,
    slot int not null,
    primary key(course_id, day_of_week, slot)
);

CREATE TABLE student_record(
    student_id varchar(12) primary key,
    student_name varchar(25) not null,
    yr integer not null,
    department varchar(3) not null
);

CREATE TABLE current_info(
    holder varchar(4) not null,
    sem integer not null,
    yr integer not null
);

CREATE TABLE instructors(
    teacher_id varchar(12) primary key,
    teacher_name varchar(25) not null,
    department varchar(3) not null
);

INSERT INTO current_info values('curr', 1, 2021);

-------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _insert_course_offerings()
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS $$
DECLARE
stdid varchar(12);
BEGIN

EXECUTE FORMAT('CREATE TABLE %I(
    student_id varchar(12) primary key
);', NEW.course_id||'_students');

EXECUTE FORMAT('CREATE TABLE %I(
    student_id varchar(12) primary key,
    grade int not null
);', NEW.course_id||'_grades');

for stdid in EXECUTE FORMAT('select * from student_record;') loop
EXECUTE FORMAT('GRANT SELECT on %L to %L;', NEW.course_id||'_students', stdid);
end loop;
RETURN NEW;
END;
$$;

CREATE TRIGGER insert_course_offerings
AFTER INSERT
ON course_offerings
FOR EACH ROW
EXECUTE PROCEDURE _insert_course_offerings();

-------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enrol(course_id varchar(6))
RETURNS void
LANGUAGE PLPGSQL
AS $$
DECLARE
curr record;
cred real;
BEGIN
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
EXECUTE FORMAT('SELECT c.credits from course_catalogue c where c.course_id = course_id;') into cred;
EXECUTE FORMAT('INSERT INTO %I values(%L, %L, %L, %L);', current_user||'_enr', course_id, curr.sem, curr.yr, cred);
END;
$$;

-------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_cgpa()
RETURNS real
LANGUAGE PLPGSQL
AS $$
DECLARE
r record;
grade real;
cred real;
BEGIN
grade :=0;
cred :=0;
for r in EXECUTE FORMAT('SELECT * FROM %I;', current_user||'_tt') loop
grade := grade + r.credits*r.grade;
cred := cred + r.credits;
END loop;
IF cred = 0 THEN
RETURN 0;
END IF;
RETURN grade/cred;
END;
$$;

-------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_prev_creds()
RETURNS real
LANGUAGE PLPGSQL
AS $$
DECLARE
cred1 real;
cred2 real;
curr record;
r record;
BEGIN
cred1 :=0;
cred2 :=0;
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
for r in EXECUTE FORMAT('SELECT * FROM %I;', current_user||'_tt') loop
IF curr.sem = 1 THEN
IF r.sem = 1 and r.yr = (curr.yr - 1) THEN
cred2 := cred2 + r.credits;
END IF;
IF r.sem = 2 and r.yr = (curr.yr - 1) THEN
cred1 := cred1 + r.credits;
END IF;

ELSE
IF r.sem = 1 and r.yr = curr.yr THEN
cred1 := cred1 + r.credits;
END IF;
IF r.sem = 2 and r.yr = (curr.yr - 1) THEN
cred2 := cred2 + r.credits;
END IF;
END IF;

END loop;
IF cred1 = 0 THEN
cred1 = 18;
END IF;
IF cred2 = 0 THEN
cred2 = 18;
END IF;

RETURN (cred1+cred2)/2.0;
END;
$$;

-------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION _check_enrol()
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS $$
DECLARE
curr record;
cgpa real;
criteria real;
cred real;
curr_cred real;
flag integer;
r record;
s record;
prereq varchar(6);
BEGIN
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
IF NEW.course_id NOT IN (select course_offerings.course_id from course_offerings) THEN
RAISE EXCEPTION 'Course does not exist!';
END IF;

IF NEW.credits NOT IN (select course_offerings.credits from course_offerings where course_offerings.course_id = NEW.course_id) THEN
RAISE EXCEPTION 'Incorrect Credits value!';
END IF;

IF NEW.sem != curr.sem THEN
RAISE EXCEPTION 'Incorrect Semester!';
END IF;

IF NEW.yr != curr.yr THEN
RAISE EXCEPTION 'Incorrect Year!';
END IF;

SELECT get_cgpa() into cgpa;
SELECT cgpa_criteria FROM course_offerings where NEW.course_id = course_offerings.course_id into criteria;
IF cgpa<criteria THEN
RAISE EXCEPTION 'CGPA too low!';
END IF;

flag := 0;
SELECT * from student_record where current_user = student_record.student_id into s;
for r in EXECUTE FORMAT('SELECT * FROM batch_req where NEW.course_id = batch_req.course_id;') loop
IF r.yr = s.yr and r.department = s.department THEN
flag := 1;
END IF;
END LOOP;
IF flag = 0 THEN
RAISE EXCEPTION 'Your batch is ineligible for this course!';
END IF;

FOR prereq in EXECUTE FORMAT('SELECT prereq from prerequisite where NEW.course_id = prerequisite.course_id;') loop
IF NOT EXISTS IN EXECUTE FORMAT('SELECT * FROM %I where prereq = %I.course_id;', current_user||'_tt', current_user||'_tt') THEN
RAISE EXCEPTION 'Prerequisites not matched!';
END IF;
END loop;

SELECT get_prev_creds() into cred;
EXECUTE FORMAT('SELECT SUM(credits) from %I;', current_user||'_enr') into curr_cred;
IF curr_cred + NEW.credits > 1.25*cred THEN
RAISE EXCEPTION 'Credit limit crossed! Raise a ticket.';
END IF;
RETURN NEW;
END;
$$;

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION new_student(student_id varchar(12), student_name varchar(25), yr integer, department varchar(3))
RETURNS void
LANGUAGE PLPGSQL
AS $$

DECLARE
cid varchar(6);

BEGIN
--Create student user
EXECUTE FORMAT('CREATE USER %I WITH ENCRYPTED PASSWORD ''pass'';', student_id);

--Insert into student records
EXECUTE FORMAT('INSERT INTO student_record values(%L, %L, %L, %L);', student_id, student_name, yr, department);

--Enrollment table
EXECUTE FORMAT('CREATE TABLE %I(
    course_id varchar(6),
    sem integer not null,
    year integer not null,
    credits real not null,
    primary key(course_id, sem, year)
);', student_id||'_enr');

--Transcript table
EXECUTE FORMAT('CREATE TABLE %I(
    course_id varchar(6),
    sem integer not null,
    year integer not null,
    credits real not null,
    grade integer not null,
    primary key(course_id)
);', student_id||'_tt');

--Ticket table
EXECUTE FORMAT('CREATE TABLE %I(
    course_id varchar(6) not null,
    sem integer not null,
    year integer not null,
    approval varchar(30) not null,
    primary key(course_id, sem, year, approval)
);', student_id||'_ticket');

EXECUTE FORMAT('GRANT SELECT on %I to %I;', student_id||'_enr', student_id);
EXECUTE FORMAT('GRANT INSERT on %I to %I;', student_id||'_enr', student_id);

EXECUTE FORMAT('GRANT SELECT on %I to %I;', student_id||'_tt', student_id);

EXECUTE FORMAT('GRANT SELECT on %I to %I;', student_id||'_ticket', student_id);
EXECUTE FORMAT('GRANT INSERT on %I to %I;', student_id||'_ticket', student_id);

EXECUTE FORMAT('GRANT SELECT on course_catalogue to %I;', student_id);
EXECUTE FORMAT('GRANT SELECT on course_offerings to %I;', student_id);
EXECUTE FORMAT('GRANT SELECT on prerequisite to %I;', student_id);
EXECUTE FORMAT('GRANT SELECT on batch to %I;', student_id);
EXECUTE FORMAT('GRANT SELECT on time_table to %I;', student_id);
EXECUTE FORMAT('GRANT SELECT on current_info to %I;', student_id);

for cid in EXECUTE FORMAT('select course_id from course_offerings;') loop
EXECUTE FORMAT('GRANT SELECT on %I to %I;', cid||'_students', student_id);
end loop;

EXECUTE FORMAT('CREATE TRIGGER %I
BEFORE INSERT
ON %I
FOR EACH ROW
EXECUTE PROCEDURE _check_enrol();', student||'_trig', student_id||'_enr');

END;
$$;
