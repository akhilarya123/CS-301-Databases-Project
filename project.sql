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

CREATE TABLE current_info(
    holder varchar(4) not null,
    sem integer not null,
    yr integer not null
);

CREATE TABLE instructor_record(
    teacher_id varchar(12) primary key,
    teacher_name varchar(25) not null,
    department varchar(3) not null
);

INSERT INTO current_info values('curr', 1, 2021);

-------------------------------------------------------------------------------------

CREATE USER dean WITH ENCRYPTED PASSWORD 'pass';
CREATE ROLE BA;
CREATE ROLE INS;
CREATE ROLE STD;

GRANT BA to dean WITH ADMIN OPTION;
GRANT INS to dean WITH ADMIN OPTION;
GRANT STD to dean WITH ADMIN OPTION;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO dean;
GRANT USAGE ON schema public to dean;

GRANT SELECT ON course_offerings, course_catalogue, prerequisite, batch_req, time_table, student_record,
current_info, instructor_record to BA, STD, INS;

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
);', NEW.course_id||'_'||NEW.section_id||'_students');

EXECUTE FORMAT('CREATE TABLE %I(
    student_id varchar(12) primary key,
    grade int not null
);', NEW.course_id||'_'||NEW.section_id||'_grades');


EXECUTE FORMAT('GRANT SELECT ON %I TO BA, STD, INS;', NEW.course_id||'_'||NEW.section_id||'_students'); 
EXECUTE FORMAT('GRANT INSERT, UPDATE, DELETE, SELECT ON %I TO %I;', NEW.course_id||'_'||NEW.section_id||'_grades', NEW.teacher_id); 

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
for r in EXECUTE FORMAT('SELECT * FROM %I;', current_user||'_tt') into r loop
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
for r in EXECUTE FORMAT('SELECT * FROM %I;', current_user||'_tt') into r loop
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
t record;
prereq varchar(6);
BEGIN
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

r:=row(null);
FOR prereq in EXECUTE FORMAT('SELECT prereq from prerequisite where NEW.course_id = prerequisite.course_id;') loop
EXECUTE FORMAT('SELECT * FROM %I where prereq = %I.course_id;', current_user||'_tt', current_user||'_tt') INTO r;
IF r is null THEN
RAISE EXCEPTION 'Prerequisites not matched!';
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
    sec_id integer not null,
    sem integer not null,
    yr integer not null,
    time_stamp TIMESTAMP not null,
    approval varchar(30) not null,
    
    primary key(course_id, sem, yr, approval)
);', student_id||'_ticket');

EXECUTE FORMAT('GRANT SELECT on %I to %I;', student_id||'_enr', student_id);
EXECUTE FORMAT('GRANT INSERT on %I to %I;', student_id||'_enr', student_id);

EXECUTE FORMAT('GRANT SELECT on %I to %I;', student_id||'_tt', student_id);

EXECUTE FORMAT('GRANT SELECT on %I to %I;', student_id||'_ticket', student_id);
EXECUTE FORMAT('GRANT INSERT on %I to %I;', student_id||'_ticket', student_id);

EXECUTE FORMAT('CREATE TRIGGER %I
BEFORE INSERT
ON %I
FOR EACH ROW
EXECUTE PROCEDURE _check_enrol();', student_id||'_trig', student_id||'_enr');

END;
$$;

---------------------------------------------------------------------------------------

-- 4 level of requests
-- studentid_lvl1, instructorid_lvl2, ....
-- lvl1 access to students and so on

/*
create table lvl1_student_id(
    credits real not null,
    teacher_id varchar(12) not null,
    course_id integer not null,
    sec_id integer not null,
    approval varchar(50) not null,
    primary key(course_id)
);

create table lvl2_teacher_id(
    credits real not null,
    student_id varchar(12) not null,
    course_id integer not null,
    sec_id integer not null,
    approval varchar(50) not null,
    primary key(course_id)
);

create table lvl3_batch_adv_id(
    credits real not null,
    student_id varchar(12) not null,
    course_id integer not null,
    sec_id integer not null,
    approval varchar(50) not null,
    primary key(course_id)
);

create table lvl4_dean(
    credits real not null,
    student_id varchar(12) not null,
    course_id integer not null,
    sec_id integer not null,
    approval varchar(50) not null,
    primary key(course_id)
);
*/

-- CREATE OR REPLACE FUNCTION generate_ticket(teacher_id varchar(12), course_id int, sec_id int)
-- RETURNS void
-- LANGUAGE PLPGSQL
-- AS $$
-- DECLARE
-- credits_curr real;
-- BEGIN
-- -- insert a tuple into student request table
-- select credits_curr into  from course_catalogue where course_catalogue.course_id = course_id;
-- execute format('INSERT INTO %I values(%L, %L, %L, %L, %L)', 'lvl1_' || current_user, credits_curr, teacher_id, course_id, sec_id, 'Waiting Approval');
-- execute format('INSERT INTO %I values(%L, %L, %L, %L, %L)', 'lvl2_' || teacher_id, credits_curr, current_user, course_id, sec_id, 'Waiting Approval');
-- RETURN cnt;
-- END;
-- $$;

-- /*
-- table for lvl2(
--     student_id,
--     course,
--     sec,
--     approval
-- )
-- */
-- CREATE OR REPLACE FUNCTION lvl2()
-- RETURNS TRIGGER
-- LANGUAGE PLPGSQL
-- AS $$
-- DECLARE
-- BEGIN

-- if NEW.approval = 'Waiting for approval' then
-- raise notice 'request queued !';

-- elsif NEW.approval = 'Approved' then
-- execute format('INSERT INTO %I values(%L, %L, %L, %L, %L)', 'lvl1_' || current_user, credits_curr, teacher_id, course_id, sec_id, 'Request approved');
-- execute format('INSERT INTO %I values(%L, %L, %L, %L, %L)', 'lvl3_' || substr(current_user, 1, 7), credits_curr, teacher_id, course_id, sec_id, 'Request approved');

-- else
-- execute format('INSERT INTO %I values(%L, %L, %L, %L, %L)', 'lvl1_' || current_user, credits_curr, teacher_id, course_id, sec_id, 'Denied request');
-- end if;

-- RETURN NEW;
-- END;
-- $$;

-- CREATE TRIGGER teacher_id_rt
-- AFTER INSERT
-- ON lvl2_teacher_id
-- FOR EACH ROW
-- EXECUTE PROCEDURE lvl2();

-- CREATE OR REPLACE FUNCTION lvl3()
-- RETURNS TRIGGER
-- LANGUAGE PLPGSQL
-- AS $$
-- DECLARE
-- BEGIN

-- RETURN NEW;
-- END;
-- $$;

-- CREATE TRIGGER batch_adv_id_rt
-- AFTER INSERT
-- ON lvl3_batch_adv_id
-- FOR EACH ROW
-- EXECUTE PROCEDURE lvl3();

-- EXECUTE FORMAT('CREATE TABLE %I(
--     course_id varchar(6) not null,
--     sec_id integer not null,
--     sem integer not null,
--     year integer not null,
--     ts TIMESTAMP not null,
--     approval varchar(30) not null,
--     primary key(course_id, sem, year, approval)
-- );', student_id||'_ticket');

CREATE OR REPLACE FUNCTION generate_ticket(req_course_id varchar(6), req_sec_id int)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
req_sem, req_year, instructor_id int;
BEGIN
select course_offerings.sem, course_offerings.yr, course_offerings.instructor_id into (req_sem, req_year, instructor_id) from course_offerings where course_offerings.course_id = req_course_id and course_offerings.sec_id = req_sec_id;
execute format('INSERT into %I values(%L, %L, %L, %L, %L, %L);', instructor_id || '_ticket', req_course_id, req_sec_id, req_sem, req_year, now(), 'waiting');
END;
$$;

CREATE OR REPLACE FUNCTION approve_ticket_instructor(req_course_id varchar(6), req_sec_id int)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
req_sem, req_year, instructor_id int;
BEGIN
select course_offerings.sem, course_offerings.yr, course_offerings.instructor_id into (req_sem, req_year, instructor_id) from course_offerings where course_offerings.course_id = req_course_id and course_offerings.sec_id = req_sec_id;
execute format('INSERT into %I values(%L, %L, %L, %L, %L, %L);', instructor_id || '_ticket', req_course_id, req_sec_id, req_sem, req_year, now(), 'waiting');
END;
$$;



-----------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION get_grades_from_csv(course_id varchar(6), section_id int, file_name varchar(50))
RETURNS void
LANGUAGE PLPGSQL
AS $$

BEGIN

EXECUTE FORMAT('COPY  %I FROM %L  DELIMITER %L CSV HEADER ;', course_id||'_'||section_id||'_grades',file_name,',');
END;
$$;
