begin;

select plan(1);

select pass('pgTAP executes against the local database');

select * from finish();

rollback;
