 INSERT INTO course_catalogue VALUES ('cs301',4,2,1,1,4);
 INSERT INTO course_catalogue VALUES ('cs302',4,2,1,1,4);
 INSERT INTO course_catalogue VALUES ('cs303',2,2,1,1,3);
 INSERT INTO course_catalogue VALUES ('cs201',3,2,1,1,3);
 INSERT INTO course_catalogue VALUES ('cs304',3,2,1,1,3);
 INSERT INTO course_catalogue VALUES ('ge103',3,2,1,1,6);
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
 select new_course_offering('cs301',1,'ins1',0); 
 INSERT INTO batch_req VALUES ('cs301','cs',2019);
 INSERT INTO batch_req VALUES ('cs301','ec',2019);
 select new_course_offering('cs302',1,'ins2',0); 
 INSERT INTO batch_req VALUES ('cs302','cs',2019);
 INSERT INTO batch_req VALUES ('cs302','ec',2019);
 select new_course_offering('cs303',1,'ins3',0);
 INSERT INTO batch_req VALUES ('cs303','cs',2019);
 INSERT INTO batch_req VALUES ('cs303','ec',2019);
 select new_course_offering('cs304',1,'ins4',0);
 INSERT INTO batch_req VALUES ('cs304','cs',2019);
 INSERT INTO batch_req VALUES ('cs304','ec',2019);
 select new_course_offering('cs201',1,'ins5',0);
 INSERT INTO batch_req VALUES ('cs201','ec',2019);
 INSERT INTO batch_req VALUES ('cs201','me',2019);
 select new_course_offering('ge103',1,'ins6',0);
 INSERT INTO batch_req VALUES ('ge103','ec',2019);
 INSERT INTO batch_req VALUES ('ge103','me',2019);
 
 
 
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
 
 
 
 
 \c - csb1;
 select enrol('cs301',1);
 select enrol('cs302',1);
 select enrol('cs303',1);
 select enrol('cs304',1);
 \c - csb5;
 select enrol('cs301',1);
 select enrol('cs302',1);
 select enrol('cs303',1);
 select enrol('cs304',1);
 select enrol('ge103',1);
 -- select enrol('cs201',1); This will give error , credits limit is exceeded for this student , to enroll generate ticket
 
 
 
 
