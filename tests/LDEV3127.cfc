/**
 * Based on https://luceeserver.atlassian.net/browse/LDEV-3127
 * Tests that RAISERROR is properly surfaced as a CFML exception with the jTDS driver.
 * Adapted from Lucee test suite: original requires mssql.modern mode for the mssql driver path,
 * this version only tests the jtds driver and works without that flag.
 */
component extends = "org.lucee.cfml.test.LuceeTestCase" labels="jtds" {

	function run( testResults, textbox ){
		if ( !hasCredentials() ) return;

		var ds = getJtdsDatasource();

		describe("LDEV-3127: RAISERROR handling with jTDS driver", function(){
			it(title = "Should throw custom RAISERROR", body = function ( currentSpec ){
				var exceptionMessage = "[no exception found]";

				try {
					query datasource=ds {
						echo("
							select 1

							raiserror('Oops! Something went wrong!', 16, 1);
						");
					}
				} catch (Any e){
					exceptionMessage = e.message;
				}

				expect(exceptionMessage).toBe("Oops! Something went wrong!", "Unexpected exception message!");
			});

			it(title = "Should throw custom RAISERROR when multiple statements", body = function ( currentSpec ){
				var exceptionMessage = "[no exception found]";

				try {
					query datasource=ds {
						echo("
							declare @test table(id int primary key)
							insert into @test (id) values (2), (3), (1)

							raiserror('Oops! Something went wrong!', 16, 1);

							select id from @test order by id asc
						");
					}
				} catch (Any e){
					exceptionMessage = e.message;
				}

				expect(exceptionMessage).toBe("Oops! Something went wrong!", "Unexpected exception message!");
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
