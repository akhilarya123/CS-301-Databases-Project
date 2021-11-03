 INSERT INTO course_catalogue VALUES ('cs301',4,2,1,1,4);
 INSERT INTO course_catalogue VALUES ('cs302',4,2,1,1,4);
 INSERT INTO course_catalogue VALUES ('cs303',2,2,1,1,3);
 INSERT INTO course_catalogue VALUES ('cs304',3,2,1,1,3);
 INSERT INTO course_catalogue VALUES ('cs201',3,2,1,1,3);
 INSERT INTO course_catalogue VALUES ('ge103',3,2,1,1,4);
 INSERT INTO course_catalogue VALUES ('ge104',3,2,1,1,4);
 INSERT INTO course_catalogue VALUES ('ge105',3,2,1,1,4);
 INSERT INTO course_catalogue VALUES ('ge106',3,2,1,1,4);
 select new_student('csb1','akhil',2019,'cs');
 select new_student('csb2','adi',2019,'cs');
 select new_student('csb3','rahul',2019,'me');
 select new_student('csb4','rohan',2019,'me');
 select new_student('csb5','raghav',2019,'ec');
 select new_student('csb6','raghav',2019,'ec');


 select new_instructor('ins1','gunturi','cs');
 select new_instructor('ins2','hansan','cs');
 select new_instructor('ins3','dewan','cs');
 select new_instructor('ins4','mathpal','cs');
 select new_instructor('ins5','sarit','me');
 select new_instructor('ins6','robert','cs');
 
 
 select new_batch_advisor('ba1','shyam','cs');
 select new_batch_advisor('ba2','satyam','mnc');
 select new_batch_advisor('ba3','shivam','mec');
 select new_batch_advisor('ba4','sundaram','ee');
 select new_batch_advisor('ba5','shiv','cvl');
 select new_batch_advisor('ba6','shishir','mmb');
 
 
 
 
 
 select new_course_offering('cs301',1,'ins1',0); 
 INSERT INTO batch_req VALUES ('cs301','cs',2019);
 INSERT INTO batch_req VALUES ('cs301','ec',2019);
 select new_course_offering('cs302',1,'ins1',0); 
 INSERT INTO batch_req VALUES ('cs302','cs',2019);
 INSERT INTO batch_req VALUES ('cs302','ec',2019);
 select new_course_offering('cs303',1,'ins1',0);
 INSERT INTO batch_req VALUES ('cs303','cs',2019);
 INSERT INTO batch_req VALUES ('cs303','ec',2019);
 select new_course_offering('cs304',1,'ins1',0);
 INSERT INTO batch_req VALUES ('cs304','cs',2019);
 INSERT INTO batch_req VALUES ('cs304','ec',2019);
 select new_course_offering('cs201',1,'ins1',0);
 INSERT INTO batch_req VALUES ('cs201','cs',2019);
 INSERT INTO batch_req VALUES ('cs201','me',2019);
 select new_course_offering('ge103',1,'ins1',0);
 INSERT INTO batch_req VALUES ('ge103','cs',2019);
 INSERT INTO batch_req VALUES ('ge103','me',2019);
  select new_course_offering('ge104',1,'ins1',0); 
 INSERT INTO batch_req VALUES ('ge104','cs',2019);
 INSERT INTO batch_req VALUES ('cs301','ec',2019);
  select new_course_offering('ge105',1,'ins1',0); 
 INSERT INTO batch_req VALUES ('ge105','cs',2019);
 INSERT INTO batch_req VALUES ('cs301','ec',2019);
 select new_course_offering('ge106',1,'ins1',0); 
 INSERT INTO batch_req VALUES ('ge106','cs',2019);
 INSERT INTO batch_req VALUES ('cs301','ec',2019);
 
 
 INSERT INTO time_table VALUES ('cs201',1,1);
 INSERT INTO time_table VALUES ('cs201',1,2);
 INSERT INTO time_table VALUES ('cs201',1,3);
 INSERT INTO time_table VALUES ('ge103',1,4);
 INSERT INTO time_table VALUES ('ge103',1,5);
 INSERT INTO time_table VALUES ('ge103',1,6);
 INSERT INTO time_table VALUES ('cs301',1,7);
 INSERT INTO time_table VALUES ('cs301',1,8);
 INSERT INTO time_table VALUES ('cs301',1,9);
 INSERT INTO time_table VALUES ('cs302',1,10);
 INSERT INTO time_table VALUES ('cs302',2,1);
 INSERT INTO time_table VALUES ('cs302',2,2);
 INSERT INTO time_table VALUES ('cs303',2,3);
 INSERT INTO time_table VALUES ('cs303',2,4);
 INSERT INTO time_table VALUES ('cs303',2,5);

 INSERT INTO time_table VALUES ('cs304',2,6);
 INSERT INTO time_table VALUES ('cs304',2,7);

 INSERT INTO time_table VALUES ('cs303',1,1);
 INSERT INTO time_table VALUES ('cs304',1,2);
 
 
 
 -- Case 1
 
 
 
 \c - csb1;
 select enrol('cs301',1);
 select enrol('cs302',1);
 select enrol('cs303',1);
 select enrol('cs304',1);
 select enrol('cs201',1);
 select enrol('ge103',1);
 select enrol('ge104',1);
 select enrol('ge105',1);
 select enrol('ge106',1);
 \c - csb5;
 select enrol('cs301',1);
 select enrol('cs302',1);
 select enrol('cs303',1);
 select enrol('cs304',1);
 select enrol('ge103',1);
 -- select enrol('cs201',1); This will give error , credits limit is exceeded for this student , to enroll generate ticket
 
 
 
 
-- Case 2


insert into csb1_tt values ('ge103',1,2019,4.5,0);
insert into csb1_tt values ('cs201',1,2020,4,8);
insert into csb1_tt values ('cs301',1,2021,3,4);
insert into csb1_tt values ('cs303',1,2021,3,7);
insert into csb1_tt values ('cs302',2,2021,3,10);
insert into csb1_tt values ('cs304',2,2021,3,9);


insert into csb2_tt values ('ge103',1,2019,4.5,8);
insert into csb2_tt values ('cs201',1,2020,4,2);
insert into csb2_tt values ('cs301',1,2021,3,8);
insert into csb2_tt values ('cs303',1,2021,3,9);
insert into csb2_tt values ('cs302',2,2021,3,9);
insert into csb2_tt values ('cs304',2,2021,3,9);

insert into csb3_tt values ('ge103',1,2019,4.5,6);
insert into csb3_tt values ('cs201',1,2020,4,5);
insert into csb3_tt values ('cs301',1,2021,3,5);
insert into csb3_tt values ('cs303',1,2021,3,6);
insert into csb3_tt values ('cs302',2,2021,3,6);
insert into csb3_tt values ('cs304',2,2021,3,5);

insert into csb4_tt values ('ge103',1,2019,4.5,7);
insert into csb4_tt values ('cs201',1,2020,4,9);
insert into csb4_tt values ('cs301',1,2021,3,9);
insert into csb4_tt values ('cs303',1,2021,3,9);
insert into csb4_tt values ('cs302',2,2021,3,9);
insert into csb4_tt values ('cs304',1,2021,3,10);













 INSERT INTO course_catalogue VALUES ('cs301',4,2,1,1,4);
 INSERT INTO course_catalogue VALUES ('cs302',4,2,1,1,4);
 INSERT INTO course_catalogue VALUES ('cs303',2,2,1,1,3);
 INSERT INTO course_catalogue VALUES ('cs304',3,2,1,1,3);
 INSERT INTO course_catalogue VALUES ('cs201',3,2,1,1,3);
 INSERT INTO course_catalogue VALUES ('ge103',3,2,1,1,4);
 INSERT INTO course_catalogue VALUES ('ge104',3,2,1,1,4);
 INSERT INTO course_catalogue VALUES ('ge105',3,2,1,1,4);
 INSERT INTO course_catalogue VALUES ('ge106',3,2,1,1,4);
 select new_student('csb1','akhil',2019,'cs');
 select new_instructor('ins1','gunturi','cs');
 select new_batch_advisor('ba1','shyam','cs');
insert into csb1_tt VALUES ('crs11',2,2019,3,8);
insert into csb1_tt VALUES ('crs12',2,2019,3.5,6);
insert into csb1_tt VALUES ('crs13',2,2019,4,7);
insert into csb1_tt VALUES ('crs21',1,2020,3,6);
insert into csb1_tt VALUES ('crs22',1,2020,3.5,7);
insert into csb1_tt VALUES ('crs23',1,2020,3,8);
insert into csb1_tt VALUES ('crs31',2,2020,4.5,5);
insert into csb1_tt VALUES ('crs32',2,2020,5,10);

--CGPA CRITERIA
  select new_course_offering('cs301',1,'ins1',7.2); 
insert into csb1_tt VALUES ('crs33',1,2020,8,10);

--Batch req
insert into batch_req values('cs301', 'cs', '2020');

insert into batch_req values('cs301', 'cs', '2019');

--Prereq
insert into csb1_tt VALUES ('crs41',1,2020,2,3);
insert into prerequisite values('cs301', 'crs41');

delete from csb1_tt where course_id = 'crs41';
insert into csb1_tt VALUES ('crs41',1,2020,2,5);

--Time slot clash
insert into time_table values('cs301', 3, 5);
insert into time_table values('cs301', 3, 6);
insert into time_table values('cs308', 3, 5);
insert into time_table values('cs308', 4, 2);
insert into csb1_enr values('cs308', 1, 1, 2021, 4);


--Credit limit
  select new_course_offering('cs302',1,'ins1',0); 
  select new_course_offering('cs303',1,'ins1',0); 
  select new_course_offering('cs304',1,'ins1',0); 
  select new_course_offering('cs201',1,'ins1',0); 
  select new_course_offering('ge103',1,'ins1',0); 
  select new_course_offering('ge104',1,'ins1',0); 
  select new_course_offering('ge105',1,'ins1',0); 
  select new_course_offering('ge106',1,'ins1',0); 

 select enrol('cs301',1);
 select enrol('cs302',1);
 select enrol('cs303',1);
 select enrol('cs304',1);
 select enrol('cs201',1);
 select enrol('ge103',1);

 select enrol('ge104',1);


--Get grades

 select new_student('csb2','aditya',2019,'cs');
 select new_student('csb3','rahul',2019,'me');
 INSERT INTO ge103_1_students values('csb1');
 INSERT INTO ge103_1_students values('csb2');
 INSERT INTO ge103_1_students values('csb3');

 select get_grades_from_csv('ge103',1,'D:\grades.csv');

--Set grades

select set_grades('ge103', 1);