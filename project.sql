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
    sem int not null,
    yr int not null,
    teacher_id varchar(12) not null,
    section_id int not null,
    cgpa_criteria real,
    PRIMARY KEY(course_id, section_id)
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

CREATE TABLE instructor_record(
    teacher_id varchar(12) primary key,
    teacher_name varchar(25) not null,
    department varchar(3) not null
);

CREATE TABLE batch_advisor_record(
    ba_id varchar(12) primary key,
    ba_name varchar(25) not null,
    department varchar(3) not null
);

CREATE TABLE current_info(
    holder varchar(4) not null,
    sem integer not null,
    yr integer not null
);

CREATE TABLE dean_ticket(
    student_id varchar(12) not null,
    course_id varchar(6) not null,
    section_id integer not null,
    sem integer not null,
    yr integer not null,
    approval varchar(50) not null,
    primary key(student_id, course_id, sem, yr, approval)
);

INSERT INTO current_info values('curr', 1, 2021);

-------------------------------------------------------------------------------------

CREATE USER dean WITH ENCRYPTED PASSWORD 'pass';
CREATE ROLE BA;
CREATE ROLE INS;
CREATE ROLE STD;

-- GRANT BA to dean WITH ADMIN OPTION;
-- GRANT INS to dean WITH ADMIN OPTION;
-- GRANT STD to dean WITH ADMIN OPTION;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO dean;
ALTER USER dean SUPERUSER;

GRANT SELECT ON course_offerings, course_catalogue, prerequisite, batch_req, time_table, student_record,
current_info, instructor_record, batch_advisor_record to BA, STD, INS;
GRANT pg_read_server_files TO ins; 
GRANT pg_write_server_files TO ins; 

-------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _insert_course_offerings()
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS $$
DECLARE

BEGIN

EXECUTE FORMAT('CREATE TABLE %I(
    student_id varchar(12) primary key
);', NEW.course_id||'_'||NEW.section_id||'_students');

EXECUTE FORMAT('CREATE TABLE %I(
    student_id varchar(12) primary key,
    grade int not null
);', NEW.course_id||'_'||NEW.section_id||'_grades');


EXECUTE FORMAT('GRANT SELECT ON %I TO BA, STD, INS;', NEW.course_id||'_'||NEW.section_id||'_students'); 
EXECUTE FORMAT('GRANT INSERT, UPDATE, DELETE, SELECT ON %I TO %I;', NEW.course_id||'_'||NEW.section_id||'_grades', NEW.teacher_id); 
EXECUTE FORMAT('GRANT INSERT, UPDATE, DELETE, SELECT ON %I TO dean;', NEW.course_id||'_'||NEW.section_id||'_grades'); 
EXECUTE FORMAT('GRANT INSERT, UPDATE, DELETE, SELECT ON %I TO dean;', NEW.course_id||'_'||NEW.section_id||'_students'); 

RETURN NEW;
END;
$$;

CREATE TRIGGER insert_course_offerings
AFTER INSERT
ON course_offerings
FOR EACH ROW
EXECUTE PROCEDURE _insert_course_offerings();

-------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION new_course_offering(course_id varchar(6), section_id integer, teacher_id varchar(12), cgpa_criteria real)
RETURNS void
LANGUAGE PLPGSQL
AS $$
DECLARE
curr record;
BEGIN
IF course_id NOT IN (SELECT course_catalogue.course_id from course_catalogue) THEN
RAISE EXCEPTION 'Course ID does not exist';
END IF;
IF teacher_id NOT IN (SELECT instructor_record.teacher_id from instructor_record) THEN
RAISE EXCEPTION 'Teacher ID does not exist';
END IF;
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
EXECUTE FORMAT('INSERT INTO course_offerings values(%L, %L, %L, %L, %L, %L);', 
course_id, curr.sem, curr.yr, teacher_id, section_id, cgpa_criteria);
END;
$$;

-------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION generate_ticket(course_id varchar(6), section_id integer)
RETURNS void
LANGUAGE PLPGSQL
AS $$
DECLARE
curr record;
cred real;
BEGIN
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
EXECUTE FORMAT('SELECT c.credits from course_catalogue c where c.course_id = course_id;') into cred;
EXECUTE FORMAT('INSERT INTO %I values(%L, %L, %L, %L, %L, %L);', current_user||'_ticket', course_id, section_id, curr.sem, curr.yr, now(), 'Raised Ticket');
END;
$$;

-------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION enrol(course_id varchar(6), section_id integer)
RETURNS void
LANGUAGE PLPGSQL
AS $$
DECLARE
curr record;
cred real;
BEGIN
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
EXECUTE FORMAT('SELECT c.credits from course_catalogue c where c.course_id = %L;', course_id) into cred;
EXECUTE FORMAT('INSERT INTO %I values(%L, %L, %L, %L, %L);', current_user||'_enr', course_id, section_id, curr.sem, curr.yr, cred);
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
for r in EXECUTE FORMAT('SELECT * FROM %I;', current_user||'_tt')  loop
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

CREATE OR REPLACE FUNCTION _student_enr_before()
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
t record;
prereq varchar(6);
BEGIN
IF current_user = 'postgres' THEN
RETURN NEW;
END IF;

EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
IF NEW.course_id NOT IN (select course_offerings.course_id from course_offerings) THEN
RAISE EXCEPTION 'Course does not exist!';
END IF;

IF NEW.section_id NOT IN (select course_offerings.section_id from course_offerings) THEN
RAISE EXCEPTION 'Section does not exist!';
END IF;

IF NEW.credits NOT IN (select course_catalogue.credits from course_catalogue where course_catalogue.course_id = NEW.course_id) THEN
RAISE EXCEPTION 'Incorrect Credits value!';
END IF;

IF NEW.sem != curr.sem THEN
RAISE EXCEPTION 'Incorrect Semester!';
END IF;

IF NEW.yr != curr.yr THEN
RAISE EXCEPTION 'Incorrect Year!';
END IF;

criteria := 11;
SELECT get_cgpa() into cgpa;
SELECT cgpa_criteria FROM course_offerings where NEW.course_id = course_offerings.course_id into criteria;
IF cgpa<criteria and criteria<11 THEN
RAISE EXCEPTION 'CGPA too low! Current: %, Required: %', cgpa, criteria;
END IF;

flag := 0;
SELECT * from student_record where current_user = student_record.student_id into s;
for r in EXECUTE FORMAT('SELECT * FROM batch_req where %L = batch_req.course_id;', NEW.course_id) loop
IF r.yr = s.yr and r.department = s.department THEN
flag := 1;
END IF;
END LOOP;
r:=row(null);
SELECT * FROM batch_req where batch_req.course_id = NEW.course_id into r;
IF r is null THEN
flag := 1;
END IF;
IF flag = 0 THEN
RAISE EXCEPTION 'Your batch is ineligible for this course!';
END IF;

r:=row(null);
FOR prereq in EXECUTE FORMAT('SELECT prereq from prerequisite where prerequisite.course_id = %L;', NEW.course_id) loop
EXECUTE FORMAT('SELECT * FROM %I where  course_id = %L;', current_user||'_tt', prereq) INTO r;
IF r is null THEN
RAISE EXCEPTION 'Prerequisites not matched!';
END IF;
IF r.grade<4 THEN
RAISE EXCEPTION 'Prerequisites not matched! Failed in %.', r.course_id;
END IF;
END loop;

FOR r IN (SELECT * FROM time_table where NEW.course_id = time_table.course_id) loop
FOR s IN EXECUTE FORMAT('SELECT * FROM %I;', current_user||'_enr') loop
FOR t IN (SELECT * FROM time_table where s.course_id = time_table.course_id) loop
IF r.day_of_week = t.day_of_week and r.slot = t.slot THEN
RAISE EXCEPTION 'Time slot clash with %', s.course_id;
END IF;
END loop;
END loop;
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

CREATE OR REPLACE FUNCTION _student_enr_after()
RETURNS TRIGGER
LANGUAGE PLPGSQL SECURITY DEFINER
AS $$
DECLARE
curr record;

BEGIN
IF current_user = 'postgres' or current_user = 'dean' THEN
RETURN NEW;
END IF;
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
EXECUTE FORMAT('INSERT INTO %I VALUES(%L);', NEW.course_id||'_'||NEW.section_id||'_students', session_user);

RETURN NEW;
END;
$$;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _student_ticket_before()
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS $$
DECLARE
curr record;
cgpa real;
criteria real;
cred real;
cr real;
curr_cred real;
flag integer;
r record;
s record;
t record;
prereq varchar(6);
BEGIN
IF current_user = 'postgres' THEN
RETURN NEW;
END IF;
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
IF NEW.course_id NOT IN (select course_offerings.course_id from course_offerings) THEN
RAISE EXCEPTION 'Course does not exist!';
END IF;

IF NEW.section_id NOT IN (select course_offerings.section_id from course_offerings) THEN
RAISE EXCEPTION 'Section does not exist!';
END IF;

IF NEW.sem != curr.sem THEN
RAISE EXCEPTION 'Incorrect Semester!';
END IF;

IF NEW.yr != curr.yr THEN
RAISE EXCEPTION 'Incorrect Year!';
END IF;

criteria := 11;
SELECT get_cgpa() into cgpa;
SELECT cgpa_criteria FROM course_offerings where NEW.course_id = course_offerings.course_id into criteria;
IF cgpa<criteria and criteria<11 THEN
RAISE EXCEPTION 'CGPA too low! Current: %, Required: %', cgpa, criteria;
END IF;

flag := 0;
SELECT * from student_record where current_user = student_record.student_id into s;
for r in EXECUTE FORMAT('SELECT * FROM batch_req where %L = batch_req.course_id;', NEW.course_id) loop
IF r.yr = s.yr and r.department = s.department THEN
flag := 1;
END IF;
END LOOP;
r:=row(null);
SELECT * FROM batch_req where batch_req.course_id = NEW.course_id into r;
IF r is null THEN
flag := 1;
END IF;
IF flag = 0 THEN
RAISE EXCEPTION 'Your batch is ineligible for this course!';
END IF;

r:=row(null);
FOR prereq in EXECUTE FORMAT('SELECT prereq from prerequisite where prerequisite.course_id = %L;', NEW.course_id) loop
EXECUTE FORMAT('SELECT * FROM %I where  course_id = %L;', current_user||'_tt', prereq) INTO r;
IF r is null THEN
RAISE EXCEPTION 'Prerequisites not matched!';
END IF;
IF r.grade<4 THEN
RAISE EXCEPTION 'Prerequisites not matched! Failed in %.', r.course_id;
END IF;
END loop;

FOR r IN (SELECT * FROM time_table where NEW.course_id = time_table.course_id) loop
FOR s IN EXECUTE FORMAT('SELECT * FROM %I;', current_user||'_enr') loop
FOR t IN (SELECT * FROM time_table where s.course_id = time_table.course_id) loop
IF r.day_of_week = t.day_of_week and r.slot = t.slot THEN
RAISE EXCEPTION 'Time slot clash with %', s.course_id;
END IF;
END loop;
END loop;
END loop;

SELECT get_prev_creds() into cred;
EXECUTE FORMAT('SELECT SUM(credits) from %I;', current_user||'_enr') into curr_cred;
SELECT credits from course_catalogue where course_id = NEW.course_id into cr;
IF curr_cred + cr <= 1.25*cred THEN
RAISE EXCEPTION 'Within credit limit! Enrol normally.';
END IF;
RETURN NEW;
END;
$$;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _student_ticket_after()
RETURNS TRIGGER
LANGUAGE PLPGSQL SECURITY DEFINER
AS $$
DECLARE
curr record;
tid varchar(12);
BEGIN
IF NEW.approval = 'Approved by Instructor' or NEW.approval = 'Rejected by Instructor' or NEW.approval = 'Approved by Batch Advisor' or NEW.approval = 'Rejected by Batch Advisor' or NEW.approval = 'Approved by Dean' or NEW.approval = 'Rejected by Dean' THEN
RETURN NEW;
END IF;
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
SELECT teacher_id FROM course_offerings where NEW.course_id = course_offerings.course_id and NEW.section_id = course_offerings.section_id into tid;
EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L, %L);', tid||'_ticket', session_user, NEW.course_id, NEW.section_id, curr.sem, curr.yr, 'Pending Instructor Approval');

RETURN NEW;
END;
$$;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _instructor_ticket_before()
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS $$
DECLARE
curr record;
r record;
BEGIN
IF current_user = 'postgres' THEN
RETURN NEW;
END IF;
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
IF current_user NOT IN (SELECT teacher_id from instructor_record) THEN
RAISE EXCEPTION 'Wrong user/function!';
END IF;

IF NEW.approval != 'Approved by Instructor' AND NEW.approval != 'Rejected by Instructor' THEN
RAISE EXCEPTION 'Wrong Approval!';
END IF;

IF NEW.sem != curr.sem OR NEW.yr != curr.yr THEN
RAISE EXCEPTION 'Incorrect semester!';
END IF;

-- DO
-- $do$
-- BEGIN
r:=row(null);
EXECUTE FORMAT('SELECT * FROM %I where section_id = %L and course_id = %L and student_id = %L and approval = ''Pending Instructor Approval'';', current_user||'_ticket', NEW.section_id, NEW.course_id, NEW.student_id) into r;
IF r is null THEN
RAISE EXCEPTION 'Incorrect Values! Check again.';
END IF;
-- end;
-- $do$;
RETURN NEW;
END;
$$;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _instructor_ticket_after()
RETURNS TRIGGER
LANGUAGE PLPGSQL SECURITY DEFINER
AS $$
DECLARE
baid varchar(12);
BEGIN
IF NEW.approval = 'Pending Instructor Approval' THEN
RETURN NEW;
END IF;
SELECT batch_advisor_record.ba_id FROM batch_advisor_record, student_record where student_id = NEW.student_id and student_record.department = batch_advisor_record.department INTO baid;
EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L, %L);', baid||'_ticket', NEW.student_id, NEW.course_id, NEW.section_id, NEW.sem, NEW.yr, NEW.approval);
EXECUTE FORMAT('DELETE FROM %I WHERE student_id = %L and course_id = %L and approval = ''Pending Instructor Approval'';', session_user||'_ticket', NEW.student_id, NEW.course_id);
EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L, %L);', NEW.student_id||'_ticket', NEW.course_id, NEW.section_id, NEW.sem, NEW.yr, now(), NEW.approval);
RETURN NEW;
END;
$$;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _batch_advisor_ticket_before()
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS $$
DECLARE
curr record;
r record;
val int;
BEGIN
IF current_user = 'postgres' THEN
RETURN NEW;
END IF;
IF current_user NOT IN (SELECT ba_id from batch_advisor_record) THEN
RAISE EXCEPTION 'Wrong user/function!';
END IF;

IF NEW.approval != 'Approved by Batch Advisor' AND NEW.approval != 'Rejected by Batch Advisor' THEN
RAISE EXCEPTION 'Wrong Approval!';
END IF;

EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
IF NEW.sem != curr.sem OR NEW.yr != curr.yr THEN
RAISE EXCEPTION 'Incorrect semester!';
END IF;
val := 2;
-- DO
-- $do$
-- BEGIN
r:=row(null);
EXECUTE FORMAT('SELECT * FROM %I where section_id = %L and course_id = %L and student_id = %L and approval = ''Approved by Instructor'';', current_user||'_ticket', NEW.section_id, NEW.course_id, NEW.student_id) into r;
IF r is null THEN
val := val-1;
END IF;
r:=row(null);
EXECUTE FORMAT('SELECT * FROM %I where section_id = %L and course_id = %L and student_id = %L and approval = ''Rejected by Instructor'';', current_user||'_ticket', NEW.section_id, NEW.course_id, NEW.student_id) into r;
IF r is null THEN
val := val-1;
END IF;
IF val = 0 THEN
RAISE EXCEPTION 'Incorrect Values! Check again.';
END IF;
-- end;
-- $do$;
RETURN NEW;
END;
$$;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _batch_advisor_ticket_after()
RETURNS TRIGGER
LANGUAGE PLPGSQL SECURITY DEFINER
AS $$
DECLARE
approv varchar(50);
BEGIN
IF NEW.approval = 'Approved by Instructor' or NEW.approval = 'Rejected by Instructor' THEN
RETURN NEW;
END IF;
EXECUTE FORMAT('SELECT approval from %I WHERE student_id = %L and course_id = %L and approval = ''Approved by Instructor'' or approval = ''Rejected by Instructor'';', session_user||'_ticket', NEW.student_id, NEW.course_id) into approv;
EXECUTE FORMAT('INSERT INTO dean_ticket VALUES(%L, %L, %L, %L, %L, %L);', NEW.student_id, NEW.course_id, NEW.section_id, NEW.sem, NEW.yr, approv);
EXECUTE FORMAT('INSERT INTO dean_ticket VALUES(%L, %L, %L, %L, %L, %L);', NEW.student_id, NEW.course_id, NEW.section_id, NEW.sem, NEW.yr, NEW.approval);
EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L, %L);', NEW.student_id||'_ticket', NEW.course_id, NEW.section_id, NEW.sem, NEW.yr, now(), NEW.approval);
EXECUTE FORMAT('DELETE FROM %I WHERE student_id = %L and course_id = %L and approval = ''Approved by Instructor'';', session_user||'_ticket', NEW.student_id, NEW.course_id);
EXECUTE FORMAT('DELETE FROM %I WHERE student_id = %L and course_id = %L and approval = ''Rejected by Instructor'';', session_user||'_ticket', NEW.student_id, NEW.course_id);
RETURN NEW;
END;
$$;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _dean_ticket_before()
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS $$
DECLARE
curr record;
r record;
val int;
BEGIN
IF current_user = 'postgres' THEN
RETURN NEW;
END IF;
IF NEW.approval != 'Approved by Dean' AND NEW.approval != 'Rejected by Dean' THEN
RAISE EXCEPTION 'Wrong Approval!';
END IF;

EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
IF NEW.sem != curr.sem OR NEW.yr != curr.yr THEN
RAISE EXCEPTION 'Incorrect semester!';
END IF;

val := 2;
-- DO
-- $do$
-- BEGIN
r:=row(null);
EXECUTE FORMAT('SELECT * FROM %I where section_id = %L and course_id = %L and student_id = %L and approval = ''Approved by Instructor'';', 'dean_ticket', NEW.section_id, NEW.course_id, NEW.student_id) into r;
IF r is null THEN
val := val-1;
END IF;
-- end;
-- $do$;
-- DO
-- $do$
-- BEGIN
r:=row(null);
EXECUTE FORMAT('SELECT * FROM %I where section_id = %L and course_id = %L and student_id = %L and approval = ''Rejected by Instructor'';', 'dean_ticket', NEW.section_id, NEW.course_id, NEW.student_id) into r;
IF r is null THEN
val := val-1;
END IF;
-- end;
-- $do$;

IF val = 0 THEN
RAISE EXCEPTION 'Waiting For Instructor Approval!';
END IF;

val := 2;
-- DO
-- $do$
-- BEGIN
r:=row(null);
EXECUTE FORMAT('SELECT * FROM %I where section_id = %L and course_id = %L and student_id = %L and approval = ''Approved by Batch Advisor'';', 'dean_ticket', NEW.section_id, NEW.course_id, NEW.student_id) into r;
IF r is null THEN
val := val-1;
END IF;
-- end;
-- $do$;
-- DO
-- $do$
-- BEGIN
r:=row(null);
EXECUTE FORMAT('SELECT * FROM %I where section_id = %L and course_id = %L and student_id = %L and approval = ''Rejected by Batch Advisor'';', 'dean_ticket', NEW.section_id, NEW.course_id, NEW.student_id) into r;
IF r is null THEN
val := val-1;
END IF;
-- end;
-- $do$;

IF val = 0 THEN
RAISE EXCEPTION 'Waiting For Batch Advisor Approval!';
END IF;

RETURN NEW;
END;
$$;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _dean_ticket_after()
RETURNS TRIGGER
LANGUAGE PLPGSQL SECURITY DEFINER
AS $$
DECLARE
cred real;
BEGIN

IF NEW.approval = 'Approved by Instructor' or NEW.approval = 'Rejected by Instructor' or NEW.approval = 'Approved by Batch Advisor' or NEW.approval = 'Rejected by Batch Advisor' THEN
RETURN NEW;
END IF;

EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L, %L);', NEW.student_id||'_ticket', NEW.course_id, NEW.section_id, NEW.sem, NEW.yr, now(), NEW.approval);

IF NEW.approval = 'Approved by Dean' THEN
EXECUTE FORMAT('INSERT INTO %I VALUES(%L);', NEW.course_id||'_'||NEW.section_id||'_students', NEW.student_id);
SELECT credits FROM course_catalogue where course_id = NEW.course_id into cred;
EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L);', NEW.student_id||'_enr', NEW.course_id, NEW.section_id, NEW.sem, NEW.yr, cred);
END IF;
EXECUTE FORMAT('DELETE FROM %I WHERE student_id = %L and course_id = %L and approval = ''Approved by Instructor'';', 'dean_ticket', NEW.student_id, NEW.course_id);
EXECUTE FORMAT('DELETE FROM %I WHERE student_id = %L and course_id = %L and approval = ''Rejected by Instructor'';', 'dean_ticket', NEW.student_id, NEW.course_id);
EXECUTE FORMAT('DELETE FROM %I WHERE student_id = %L and course_id = %L and approval = ''Approved by Batch Advisor'';', 'dean_ticket', NEW.student_id, NEW.course_id);
EXECUTE FORMAT('DELETE FROM %I WHERE student_id = %L and course_id = %L and approval = ''Rejected by Batch Advisor'';', 'dean_ticket', NEW.student_id, NEW.course_id);

RETURN NEW;
END;
$$;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION new_student(student_id varchar(12), student_name varchar(25), yr integer, department varchar(3))
RETURNS void
LANGUAGE PLPGSQL
AS $$

DECLARE

BEGIN
--Create student user
EXECUTE FORMAT('CREATE USER %I WITH ENCRYPTED PASSWORD ''pass'';', student_id);

--Insert into student records
EXECUTE FORMAT('INSERT INTO student_record values(%L, %L, %L, %L);', student_id, student_name, yr, department);

--Enrollment table
EXECUTE FORMAT('CREATE TABLE %I(
    course_id varchar(6),
    section_id integer not null,
    sem integer not null,
    yr integer not null,
    credits real not null,
    primary key(course_id, sem, yr)
);', student_id||'_enr');

--Transcript table
EXECUTE FORMAT('CREATE TABLE %I(
    course_id varchar(6),
    sem integer not null,
    yr integer not null,
    credits real not null,
    grade integer not null,
    primary key(course_id, sem, yr)
);', student_id||'_tt');

--Ticket table
EXECUTE FORMAT('CREATE TABLE %I(
    course_id varchar(6) not null,
    section_id integer not null,
    sem integer not null,
    yr integer not null,
    time_stamp TIMESTAMP not null,
    approval varchar(50) not null,
    
    primary key(course_id, sem, yr, approval)
);', student_id||'_ticket');

EXECUTE FORMAT('GRANT SELECT on %I to %I;', student_id||'_enr', student_id);
EXECUTE FORMAT('GRANT INSERT on %I to %I;', student_id||'_enr', student_id);

EXECUTE FORMAT('GRANT SELECT on %I to %I;', student_id||'_tt', student_id);
EXECUTE FORMAT('GRANT SELECT on %I to BA, INS;', student_id||'_tt');

EXECUTE FORMAT('GRANT SELECT on %I to %I;', student_id||'_ticket', student_id);
EXECUTE FORMAT('GRANT INSERT on %I to %I;', student_id||'_ticket', student_id);
EXECUTE FORMAT('GRANT STD to %I;', student_id);

-- EXECUTE FORMAT('GRANT INSERT, UPDATE, DELETE, SELECT ON %I TO dean;', student_id||'_ticket');
-- EXECUTE FORMAT('GRANT INSERT, UPDATE, DELETE, SELECT ON %I TO dean;', student_id||'_enr');
-- EXECUTE FORMAT('GRANT INSERT, UPDATE, DELETE, SELECT ON %I TO dean;', student_id||'_tt');

EXECUTE FORMAT('CREATE TRIGGER %I
BEFORE INSERT
ON %I
FOR EACH ROW
EXECUTE PROCEDURE _student_enr_before();', student_id||'_enr_before', student_id||'_enr');

EXECUTE FORMAT('CREATE TRIGGER %I
AFTER INSERT
ON %I
FOR EACH ROW
EXECUTE PROCEDURE _student_enr_after();', student_id||'_enr_after', student_id||'_enr');

EXECUTE FORMAT('CREATE TRIGGER %I
BEFORE INSERT
ON %I
FOR EACH ROW
EXECUTE PROCEDURE _student_ticket_before();', student_id||'_ticket_before', student_id||'_ticket');

EXECUTE FORMAT('CREATE TRIGGER %I
AFTER INSERT
ON %I
FOR EACH ROW
EXECUTE PROCEDURE _student_ticket_after();', student_id||'_ticket_after', student_id||'_ticket');

END;
$$;

---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION new_instructor(teacher_id varchar(12), teacher_name varchar(25), department varchar(3))
RETURNS void
LANGUAGE PLPGSQL
AS $$

BEGIN
--Create user
EXECUTE FORMAT('CREATE USER %I WITH ENCRYPTED PASSWORD ''pass'';', teacher_id);

--Insert into records
EXECUTE FORMAT('INSERT INTO instructor_record values(%L, %L, %L);', teacher_id, teacher_name, department);

--Ticket table
EXECUTE FORMAT('CREATE TABLE %I(
    student_id varchar(12) not null,
    course_id varchar(6) not null,
    section_id integer not null,
    sem integer not null,
    yr integer not null,
    approval varchar(50) not null,
    primary key(student_id, course_id, sem, yr, approval)
);', teacher_id||'_ticket');


EXECUTE FORMAT('GRANT SELECT on %I to %I;', teacher_id||'_ticket', teacher_id);
EXECUTE FORMAT('GRANT INSERT on %I to %I;', teacher_id||'_ticket', teacher_id);
EXECUTE FORMAT('GRANT INS to %I;', teacher_id);

-- EXECUTE FORMAT('GRANT INSERT, UPDATE, DELETE, SELECT ON %I TO dean;', teacher_id||'_ticket');

EXECUTE FORMAT('CREATE TRIGGER %I
BEFORE INSERT
ON %I
FOR EACH ROW
EXECUTE PROCEDURE _instructor_ticket_before();', teacher_id||'_ticket_before', teacher_id||'_ticket');

EXECUTE FORMAT('CREATE TRIGGER %I
AFTER INSERT
ON %I
FOR EACH ROW
EXECUTE PROCEDURE _instructor_ticket_after();', teacher_id||'_ticket_after', teacher_id||'_ticket');


END;
$$;

---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION new_batch_advisor(ba_id varchar(12), ba_name varchar(25), department varchar(3))
RETURNS void
LANGUAGE PLPGSQL
AS $$

BEGIN
--Create user
EXECUTE FORMAT('CREATE USER %I WITH ENCRYPTED PASSWORD ''pass'';', ba_id);

--Insert into records
EXECUTE FORMAT('INSERT INTO batch_advisor_record values(%L, %L, %L);', ba_id, ba_name, department);

--Ticket table
EXECUTE FORMAT('CREATE TABLE %I(
    student_id varchar(12) not null,
    course_id varchar(6) not null,
    section_id integer not null,
    sem integer not null,
    yr integer not null,
    approval varchar(50) not null,
    primary key(student_id, course_id, sem, yr, approval)
);', ba_id||'_ticket');


EXECUTE FORMAT('GRANT SELECT on %I to %I;', ba_id||'_ticket', ba_id);
EXECUTE FORMAT('GRANT INSERT on %I to %I;', ba_id||'_ticket', ba_id);
EXECUTE FORMAT('GRANT BA to %I;', ba_id);

EXECUTE FORMAT('CREATE TRIGGER %I
BEFORE INSERT
ON %I
FOR EACH ROW
EXECUTE PROCEDURE _batch_advisor_ticket_before();', ba_id||'_ticket_before', ba_id||'_ticket');

EXECUTE FORMAT('CREATE TRIGGER %I
AFTER INSERT
ON %I
FOR EACH ROW
EXECUTE PROCEDURE _batch_advisor_ticket_after();', ba_id||'_ticket_after', ba_id||'_ticket');


END;
$$;

---------------------------------------------------------------------------------------

CREATE TRIGGER dean_ticket_before
BEFORE INSERT
ON dean_ticket
FOR EACH ROW
EXECUTE PROCEDURE _dean_ticket_before();

CREATE TRIGGER dean_ticket_after
AFTER INSERT
ON dean_ticket
FOR EACH ROW
EXECUTE PROCEDURE _dean_ticket_after();

---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION approve_ticket_instructor(stdid varchar(12), cid varchar(6))
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
curr record;
secid int;
BEGIN
IF current_user NOT IN (SELECT teacher_id from instructor_record) THEN
RAISE EXCEPTION 'Wrong user/function!';
END IF;
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
EXECUTE FORMAT('SELECT section_id from %I where student_id = %L and course_id = %L;', current_user||'_ticket', stdid, cid) INTO secid; 
EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L, %L);', current_user||'_ticket', stdid, cid, secid, curr.sem, curr.yr, 'Approved by Instructor');
END;
$$;

---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION reject_ticket_instructor(stdid varchar(12), cid varchar(6))
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
curr record;
secid int;
BEGIN
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
EXECUTE FORMAT('SELECT section_id from %I where student_id = %L and course_id = %L;', current_user||'_ticket', stdid, cid) INTO secid; 
EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L, %L);', current_user||'_ticket', stdid, cid, secid, curr.sem, curr.yr, 'Rejected by Instructor');
END;
$$;

---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION approve_ticket_badvisor(stdid varchar(12), cid varchar(6))
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
curr record;
secid int;
BEGIN
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
EXECUTE FORMAT('SELECT section_id from %I where student_id = %L and course_id = %L;', current_user||'_ticket', stdid, cid) INTO secid; 
EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L, %L);', current_user||'_ticket', stdid, cid, secid, curr.sem, curr.yr, 'Approved by Batch Advisor');
END;
$$;

---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION reject_ticket_badvisor(stdid varchar(12), cid varchar(6))
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
curr record;
secid int;
BEGIN
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
EXECUTE FORMAT('SELECT section_id from %I where student_id = %L and course_id = %L;', current_user||'_ticket', stdid, cid) INTO secid; 
EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L, %L);', current_user||'_ticket', stdid, cid, secid, curr.sem, curr.yr, 'Rejected by Batch Advisor');
END;
$$;

---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION approve_ticket_dean(stdid varchar(12), cid varchar(6))
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
curr record;
secid int;
BEGIN
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
EXECUTE FORMAT('SELECT section_id from %I where student_id = %L and course_id = %L;', current_user||'_ticket', stdid, cid) INTO secid; 
EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L, %L);', current_user||'_ticket', stdid, cid, secid, curr.sem, curr.yr, 'Approved by Dean');
END;
$$;

---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION reject_ticket_dean(stdid varchar(12), cid varchar(6))
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
curr record;
secid int;
BEGIN
EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
EXECUTE FORMAT('SELECT section_id from %I where student_id = %L and course_id = %L;', current_user||'_ticket', stdid, cid) INTO secid; 
EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L, %L);', current_user||'_ticket', stdid, cid, secid, curr.sem, curr.yr, 'Rejected by Dean');
END;
$$;

---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_grades_from_csv(course_id varchar(6), section_id int, file_name varchar(50))
RETURNS void
LANGUAGE PLPGSQL
AS $$

BEGIN

EXECUTE FORMAT('COPY  %I FROM %L  DELIMITER %L CSV HEADER ;', course_id||'_'||section_id||'_grades', file_name, ',');
END;
$$;

---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_grades(course_id varchar(6), section_id int)
RETURNS void
LANGUAGE PLPGSQL
AS $$
DECLARE
r record;
x record;
curr record;
cred real;
BEGIN

FOR r IN EXECUTE FORMAT('SELECT * FROM %I;', course_id||'_'||section_id||'_students') loop
-- DO
-- $do$
-- BEGIN
x := row(null);
EXECUTE FORMAT('SELECT * FROM %I WHERE student_id = %L;', course_id||'_'||section_id||'_grades', r.student_id) into x;
IF x is null THEN 
RAISE EXCEPTION 'Grade for % is not present', r.student_id;
END IF;
-- end;
-- $do$;
END loop;

FOR r IN EXECUTE FORMAT('SELECT * FROM %I;', course_id||'_'||section_id||'_grades') loop
-- DO
-- $do$
-- BEGIN
x := row(null);
EXECUTE FORMAT('SELECT * FROM %I WHERE student_id = %L;', course_id||'_'||section_id||'_students', r.student_id) into x;
IF x is null THEN
RAISE EXCEPTION 'Student % is not enrolled, yet has a grade present', r.student_id;
END IF;
-- end;
-- $do$;
END loop;

EXECUTE FORMAT('SELECT * from current_info c where c.holder = ''curr'';') into curr;
EXECUTE FORMAT('SELECT credits FROM course_catalogue WHERE course_id = %L', course_id) INTO cred; 

FOR r IN EXECUTE FORMAT('SELECT * FROM %I;', course_id||'_'||section_id||'_grades') loop
EXECUTE FORMAT('INSERT INTO %I VALUES(%L, %L, %L, %L, %L);', r.student_id||'_tt', course_id, curr.sem, curr.yr, cred, r.grade);
END loop;

END;
$$;

---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_time_table_from_csv(file_name varchar(50))
RETURNS void
LANGUAGE PLPGSQL
AS $$

BEGIN

EXECUTE FORMAT('COPY  %I FROM %L  DELIMITER %L CSV HEADER ;', 'time_table', file_name, ',');
END;
$$;

---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION show_transcript(student_id varchar(12), sem int, yr int)
RETURNS void
LANGUAGE PLPGSQL
AS $$
DECLARE
r record;
grade real;
cred real;
BEGIN
grade :=0;
cred :=0;

IF yr = 0 THEN

for r in EXECUTE FORMAT('SELECT * FROM %I;', student_id||'_tt')  loop
RAISE NOTICE 'Course: %   Sem: %   Year: %   Credits: %   Grade: %', r.course_id, r.sem, r.yr, r.credits, r.grade;
grade := grade + r.credits*r.grade;
cred := cred + r.credits;
END loop;
IF cred = 0 THEN
RAISE NOTICE 'No courses found';
RETURN;
END IF;
EXECUTE FORMAT('SELECT * FROM %I;', student_id||'_tt');
RAISE NOTICE 'CGPA is: %', grade/cred;
RAISE NOTICE 'Total Credits: %', cred;
RETURN;
END IF;

for r in EXECUTE FORMAT('SELECT * FROM %I;', student_id||'_tt')  loop
IF r.sem = sem and r.yr = yr THEN
RAISE NOTICE 'Course: %   Sem: %   Year: %   Credits: %   Grade: %', r.course_id, r.sem, r.yr, r.credits, r.grade;
grade := grade + r.credits*r.grade;
cred := cred + r.credits;
END IF;
END loop;
IF cred = 0 THEN
RAISE NOTICE 'No courses found for the selected semester';
RETURN;
END IF;
EXECUTE FORMAT('SELECT * FROM %I WHERE sem = %L and yr = %L;', student_id||'_tt', sem, yr);
RAISE NOTICE 'SGPA is: %', grade/cred;
RAISE NOTICE 'Total Credits: %', cred;
RETURN;

END;
$$;
