create sequence documents_id_seq;
select setval('documents_id_seq', 101, true);

create table documents
(
	id integer not null primary key default nextval('public.documents_id_seq'::text),
	class text not null,
	ctime timestamp not null default now(),
	mtime timestamp not null default now(),
	dtime timestamp not null default now(),
	status smallint not null default 0,
	sections integer[],
	name text,
	data text
);
create index documents_sections on documents using gist ( "sections" "gist__int_ops" );
create index documents_dtime on documents (dtime);


create table sections
(
	id integer not null primary key default nextval('public.documents_id_seq'::text),
	pid integer,
	class text not null,
	ctime timestamp not null default now(),
	mtime timestamp not null default now(),
	status smallint not null default 0,
	sorder integer default 1,
	name text,
	alias text,
	data text
);
create index sections_parent on sections (pid);
create index sections_alias_pid on sections (alias, pid);
insert into sections (id, status, sorder, class, name) values (1, 1, 1, 'Contenido::Section', 'Корневая секция');


create table links
(
	id integer not null primary key default nextval('public.documents_id_seq'::text),
	class text not null,
	ctime timestamp not null default now(),
	mtime timestamp not null default now(),
	status smallint not null default 1,
	source_id integer not null,
	source_class text not null,
	dest_id integer not null,
	dest_class text not null,
	data text
);
create index links_source on links (source_id);
create index links_dest on links (dest_id);

create table users
(
	id integer not null primary key default nextval('public.documents_id_seq'::text),
	login text not null,
	class text not null,
	ctime timestamp not null default now(),
	mtime timestamp not null default now(),
	status smallint not null default 1,
	name text,
	passwd text not null,
	groups integer[],
	data text
);
create unique index users_login on users(login);

create table options (
	id integer not null primary key default nextval('public.documents_id_seq'::text),
    pid integer,
    name text,
    value text,
    "type" text not null
);

insert into options values (1, NULL, 's_alias', NULL, 'HASH');
insert into options values (2, NULL, 'widths', NULL, 'HASH');
insert into options values (3, NULL, 'redirects', NULL, 'HASH');
insert into options values (4, NULL, 'users', NULL, 'HASH');
insert into options values (5, 4, 'Contenido::User::DefaultUser', NULL, 'HASH');
insert into options values (6, NULL, 'links', NULL, 'HASH');
insert into options values (7, 6, 'Contenido::Link::DefaultLink', NULL, 'HASH');
insert into options values (8, NULL, 'sections', NULL, 'HASH');
insert into options values (9, 8, 'Contenido::Section::DefaultSection', NULL, 'HASH');
insert into options values (10, NULL, 'colors', NULL, 'HASH');
insert into options values (11, NULL, 'tabs', NULL, 'HASH');
insert into options values (12, 11, 'admin', NULL, 'HASH');
insert into options values (13, 12, 'id', 'admin', 'SCALAR');
insert into options values (14, 12, 'sections', NULL, 'ARRAY');
insert into options values (15, 14, '0', 'Contenido::Section::DefaultSection', 'SCALAR');
insert into options values (16, 12, 'lefts', NULL, 'ARRAY');
insert into options values (17, 16, '0', 'structure', 'SCALAR');
insert into options values (18, 16, '1', 'project', 'SCALAR');
insert into options values (19, 12, 'name', 'Администрирование', 'SCALAR');
insert into options values (20, 11, 'rubricator', NULL, 'HASH');
insert into options values (21, 20, 'id', 'rubricator', 'SCALAR');
insert into options values (22, 20, 'sections', NULL, 'ARRAY');
insert into options values (23, 22, '0', 'Contenido::Section::DefaultSection', 'SCALAR');
insert into options values (24, 20, 'lefts', NULL, 'ARRAY');
insert into options values (25, 24, '0', 'finder', 'SCALAR');
insert into options values (26, 20, 'name', 'Тематический рубрикатор', 'SCALAR');
insert into options values (27, NULL, 'documents', NULL, 'HASH');
insert into options values (28, 27, 'Contenido::Document::DefaultDocument', NULL, 'HASH');
