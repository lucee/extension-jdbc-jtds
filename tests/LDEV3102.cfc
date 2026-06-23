/**
 * Based on https://luceeserver.atlassian.net/browse/LDEV-3102
 * Tests multiple-statement query behaviour with the jTDS driver.
 * Adapted from Lucee test suite: original requires mssql.modern mode for the mssql driver path,
 * this version only tests the jtds driver and works without that flag.
 */
component extends = "org.lucee.cfml.test.LuceeTestCase" labels="jtds" {

	function beforeAll(){
		if ( !hasCredentials() ) return;
		var ds = getJtdsDatasource();
		query datasource=ds {
			echo("
				drop table if exists LDEV3102;
				create table LDEV3102 (id int primary key, test varchar(20));

				drop table if exists LDEV3102_NOPKEY;
				create table LDEV3102_NOPKEY ([key] varchar(20), test varchar(20));

				drop table if exists LDEV3102_AUTOPKEY;
				create table LDEV3102_AUTOPKEY (id int identity primary key, test varchar(20));
			");
		}
	}

	public function afterAll(){
		if ( !hasCredentials() ) return;
		var ds = getJtdsDatasource();
		query datasource=ds {
			echo("
				drop table if exists LDEV3102
				drop table if exists LDEV3102_NOPKEY
				drop table if exists LDEV3102_AUTOPKEY
			");
		}
	}

	function run( testResults, textbox ){
		if ( !hasCredentials() ) return;

		var ds = getJtdsDatasource();

		describe("LDEV-3102: multiple-statement queries with jTDS", function(){
			beforeEach( function( currentSpec ){
				query datasource=ds {
					echo("
						delete from LDEV3102
						insert into LDEV3102 values (1, 'testcase');

						delete from LDEV3102_NOPKEY
						insert into LDEV3102_NOPKEY values ('fb1b5fc5e', 'testcase');
					");
				}
			});

			it(title = "Select operation in cfquery with name only", body = function ( currentSpec ){
				query name="local.recordset" datasource=ds {
					echo("select * from LDEV3102");
				}
				expect(recordset.columnData("id")).toBe([1]);
			});

			it(title = "Insert and Select operation in cfquery with name only", body = function ( currentSpec ){
				query name="local.recordset" datasource=ds {
					echo("
						insert into LDEV3102 values (2,'inserted')
						select * from LDEV3102 order by id
					");
				}
				expect(recordset.columnData("id")).toBe([1, 2]);
			});

			it(title = "Select operation in cfquery with name and result attribute", body = function ( currentSpec ){
				query name="local.recordset" result="local.result" datasource=ds {
					echo("select * from LDEV3102");
				}
				expect(recordset.columnData("id")).toBe([1]);
			});

			it(title = "Insert and Select operation in cfquery with name and result attribute", body = function ( currentSpec ){
				query name="local.recordset" result="local.result" datasource=ds {
					echo("
						insert into LDEV3102 values (2, 'inserted')
						select * from LDEV3102 order by id
					");
				}
				expect(recordset.columnData("id")).toBe([1, 2]);
			});

			it(title = "Table variable with insert should return values with name only", body = function ( currentSpec ){
				query name="local.recordset" datasource=ds {
					echo("
						declare @test table(id int primary key)
						insert into @test (id) values (2), (3), (1)
						select id from @test order by id asc
					");
				}
				expect(recordset.columnData("id")).toBe([1, 2, 3]);
			});

			it(title = "Table variable with insert should return values but not generatedKey", body = function ( currentSpec ){
				query name="local.recordset" result="local.result" datasource=ds {
					echo("
						declare @test table(id int primary key)
						insert into @test (id) values (2), (3), (1)
						select id from @test order by id asc
					");
				}
				expect(structKeyExists(result, "generatedKey")).toBeFalse();
			});

			it(title = "Conditional insert/select should return new record as being inserted", body = function ( currentSpec ){
				query name="local.recordset" datasource=ds {
					echo("
						if( not exists( select 1 from LDEV3102_NOPKEY where [key] = 'ba8668b9b') )
							begin
								insert into LDEV3102_NOPKEY ( [key] ) values ( 'ba8668b9b' )
								select 1 as inserted
							end
						else
							begin
								select 0 as inserted
							end
					");
				}
				expect(recordset.columnData("inserted")).toBe([1]);
			});

			it(title = "Conditional insert/select should not return generatedKey", body = function ( currentSpec ){
				query name="local.recordset" result="local.result" datasource=ds {
					echo("
						if( not exists( select 1 from LDEV3102_NOPKEY where [key] = 'ba8668b9b') )
							begin
								insert into LDEV3102_NOPKEY ( [key] ) values ( 'ba8668b9b' )
								select 1 as inserted
							end
						else
							begin
								select 0 as inserted
							end
					");
				}
				expect(structKeyExists(result, "generatedKey")).toBeFalse();
			});

			it(title = "Insert with OUTPUT clause should return generatedKey", body = function ( currentSpec ){
				query name="local.recordset" result="local.result" datasource=ds {
					echo("
						insert into LDEV3102_AUTOPKEY (test) OUTPUT Inserted.id, Inserted.test values ('inserted');
					");
				}
				expect(recordset.recordCount).toBe(1, "Should return a record!");
				expect(recordset.id).toBeGT(0, "Unexpected id returned from OUTPUT clause!");
				expect(recordset.test).toBe("inserted", "Unexpected test returned from OUTPUT clause!");
				expect(result.generatedKey).toBeGT(0, "Unexpected generatedKey!");
			});

			it(title = "Multiple SELECT statements should only return first recordset", body = function ( currentSpec ){
				query name="local.recordset" datasource=ds {
					echo("
						select 1 as inserted;
						select 2 as updated;
					");
				}
				expect(recordset.columnData("inserted")).toBe([1]);
			});

			it(title = "Multiple INSERT INTO should return first generatedKey", body = function ( currentSpec ){
				query name="local.recordset" result="local.result" datasource=ds {
					echo("
						insert into LDEV3102_AUTOPKEY (test) values ('test 1');
						insert into LDEV3102_AUTOPKEY (test) values ('test 2');
					");
				}
				expect(result.generatedKey).toBeGT(0);
			});

			it(title = "Creating a temp table and dropping it should still return select statement", body = function ( currentSpec ){
				query name="local.recordset" result="local.result" datasource=ds {
					echo("
						drop table if exists ##LDEV3102_TEMP_PRIMARY
						drop table if exists ##LDEV3102_TEMP_SECONDARY

						create table ##LDEV3102_TEMP_PRIMARY (id int primary key with (IGNORE_DUP_KEY=ON), unique (id))
						create table ##LDEV3102_TEMP_SECONDARY (id int primary key with (IGNORE_DUP_KEY=ON), unique (id))

						insert into ##LDEV3102_TEMP_PRIMARY (id) values (1), (2), (3), (4), (5), (6);

						insert into ##LDEV3102_TEMP_SECONDARY
						select id from ##LDEV3102_TEMP_PRIMARY where id % 2 = 0

						select id from ##LDEV3102_TEMP_SECONDARY

						drop table ##LDEV3102_TEMP_PRIMARY
						drop table ##LDEV3102_TEMP_SECONDARY
					");
				}
				expect(recordset.columnData("id")).toBe([2, 4, 6]);
			});
		});
	}

	private boolean function hasCredentials() {
		return structCount( getCredentials() ) > 0;
	}

	private struct function getCredentials() {
		return server._getSystemPropOrEnvVars( "SERVER, USERNAME, PASSWORD, PORT, DATABASE", "MSSQL_" );
	}

	private struct function getJtdsDatasource() {
		var c = getCredentials();
		var ds = {
			class: "net.sourceforge.jtds.jdbc.Driver",
			connectionString: "jdbc:jtds:sqlserver://#c.SERVER#:#c.PORT#/#c.DATABASE#",
			username: c.USERNAME,
			password: c.PASSWORD,
			blob: true,
			clob: true,
			validate: false
		};
		if ( luceeSupportsMavenJdbc() ) {
			ds.maven = "net.sourceforge.jtds:jtds:1.3.1";
		} else {
			ds.bundleName = "net.sourceforge.jtds";
			ds.bundleVersion = "1.3.1";
		}
		return ds;
	}

	private boolean function luceeSupportsMavenJdbc() {
		try {
			return server.doesJDBCSupportMaven();
		} catch ( any e ) {
			return false;
		}
	}
}
