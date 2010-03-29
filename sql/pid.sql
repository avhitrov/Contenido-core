create table pid (
    id integer default nextval('documents_id_seq'::regclass) not null,
    mutex bigint not null,
    host text,
    state integer not null default 0,
    script text,
    pid integer,
    started timestamp without time zone,
    finished timestamp without time zone,
    ctime timestamp without time zone default ('now'::text)::timestamp(0) without time zone
);
alter table only pid add constraint pid_pkey primary key (id);
create index pid_idx1 on pid using btree (mutex, state);
