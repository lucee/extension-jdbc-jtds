component extends="org.lucee.cfml.test.LuceeTestCase" labels="jtds" {

	// keep in sync with pom.xml mvnVersion (major.minor.patch prefix)
	variables.mavenDriverVersionPrefix = "1.3.1";

	function isNotSupported() {
		return structCount( getCredentials() ) == 0;
	}

	private boolean function luceeSupportsMavenJdbc() {
		try {
			return server.doesJDBCSupportMaven();
		} catch ( any e ) {
			return false;
		}
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
			ds.maven = "net.sourceforge.jtds:jtds:#variables.mavenDriverVersionPrefix#";
		} else {
			ds.bundleName = "net.sourceforge.jtds";
			ds.bundleVersion = "#variables.mavenDriverVersionPrefix#";
		}
		return ds;
	}

	function run( testResults, testBox ) {
		describe( title="jTDS JDBC extension driver version", body=function() {
			it(
				title="loads the jTDS driver and connects to SQL Server",
				skip=isNotSupported(),
				body=function( currentSpec ) {
					var ds = getJtdsDatasource();

					dbinfo datasource=ds name="local.dbVersion" type="version";

					var info = {
						luceeVersion: server.lucee.version,
						luceeSupportsMavenJdbc: luceeSupportsMavenJdbc(),
						driverName: dbVersion.driver_name,
						driverVersion: dbVersion.driver_version,
						databaseProduct: dbVersion.database_productname,
						databaseVersion: dbVersion.database_version,
						jdbcVersion: dbVersion.jdbc_major_version & "." & dbVersion.jdbc_minor_version
					};

					systemOutput( "jTDS JDBC driver info: " & serializeJSON( info ), true );

					expect( dbVersion.recordCount ).toBe( 1 );
					expect( dbVersion.driver_name ).toInclude( "jTDS" );
					expect( dbVersion.driver_version ).toInclude( variables.mavenDriverVersionPrefix );
				}
			);

			it(
				title="executes a basic query with jTDS",
				skip=isNotSupported(),
				body=function( currentSpec ) {
					var ds = getJtdsDatasource();
					var result = queryExecute( "SELECT 1 AS val", {}, { datasource: ds } );
					expect( result.recordCount ).toBe( 1 );
					expect( result.val ).toBe( 1 );
				}
			);
		} );
	}

}
