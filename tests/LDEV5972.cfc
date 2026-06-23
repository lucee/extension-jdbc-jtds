/**
 * Based on https://luceeserver.atlassian.net/browse/LDEV-5972
 * Tests that RAISERROR is properly surfaced in modern mode, and silently ignored in legacy mode.
 * Adapted to use the jTDS driver explicitly.
 * Requires Lucee 7+ (useMSSQLModern field was added in Lucee 7).
 */
component extends="org.lucee.cfml.test.LuceeTestCase" labels="jtds" {

	variables.tableName = "ldev5972_test";

	function isNotSupported() {
		if ( !server.checkVersionGTE( server.lucee.version, 7, 0, 0, 0 ) ) return true;
		return structCount( getCredentials() ) == 0;
	}

	function afterAll() {
		if ( isNotSupported() ) return;
		var ds = getJtdsDatasource();
		queryExecute( "IF OBJECT_ID('#variables.tableName#', 'U') IS NOT NULL DROP TABLE #variables.tableName#", {}, { datasource: ds } );
	}

	function run( testResults, testBox ) {

		describe( "LDEV-5972: MSSQL RAISERROR handling with jTDS driver", function() {

			describe( "RAISERROR after SELECT", function() {
				it( title="modern=false (RAISERROR silently ignored - known limitation)", skip=isNotSupported(), body=function() {
					runRaiserrorAfterSelect( modern=false, expectedMessage="[no exception found]" );
				});
				it( title="modern=true (RAISERROR properly caught)", skip=isNotSupported(), body=function() {
					runRaiserrorAfterSelect( modern=true, expectedMessage="Oops! Something went wrong!" );
				});
			});

			describe( "RAISERROR after INSERT", function() {
				it( title="modern=false (RAISERROR silently ignored - known limitation)", skip=isNotSupported(), body=function() {
					runRaiserrorAfterInsert( modern=false, expectedMessage="[no exception found]" );
				});
				it( title="modern=true (RAISERROR properly caught)", skip=isNotSupported(), body=function() {
					runRaiserrorAfterInsert( modern=true, expectedMessage="Insert failed!" );
				});
			});

			describe( "RAISERROR with multiple statements", function() {
				it( title="modern=false (RAISERROR silently ignored - known limitation)", skip=isNotSupported(), body=function() {
					runRaiserrorMultipleStatements( modern=false, expectedMessage="[no exception found]" );
				});
				it( title="modern=true (RAISERROR properly caught)", skip=isNotSupported(), body=function() {
					runRaiserrorMultipleStatements( modern=true, expectedMessage="Multi-statement error!" );
				});
			});

		});
	}

	private function setMSSQLModern( required boolean value ) {
		var field = createObject( "java", "lucee.runtime.type.QueryImpl" ).getClass().getDeclaredField( "useMSSQLModern" );
		field.setAccessible( true );
		field.setBoolean( nullValue(), arguments.value );
	}

	private function createTestTable() {
		var ds = getJtdsDatasource();
		queryExecute( "IF OBJECT_ID('#variables.tableName#', 'U') IS NOT NULL DROP TABLE #variables.tableName#", {}, { datasource: ds } );
		queryExecute( "CREATE TABLE #variables.tableName# ( id INT IDENTITY(1,1) PRIMARY KEY, name VARCHAR(100) )", {}, { datasource: ds } );
	}

	private function runRaiserrorAfterSelect( required boolean modern, required string expectedMessage ) {
		setMSSQLModern( arguments.modern );
		var ds = getJtdsDatasource();
		var exceptionMessage = "[no exception found]";
		try {
			queryExecute(
				"SELECT 1 as col1; RAISERROR('Oops! Something went wrong!', 16, 1);",
				{},
				{ datasource: ds }
			);
		} catch ( any e ) {
			exceptionMessage = e.message;
		}
		expect( exceptionMessage ).toBe( arguments.expectedMessage );
	}

	private function runRaiserrorAfterInsert( required boolean modern, required string expectedMessage ) {
		setMSSQLModern( arguments.modern );
		createTestTable();
		var ds = getJtdsDatasource();
		var exceptionMessage = "[no exception found]";
		try {
			queryExecute(
				"INSERT INTO #variables.tableName# (name) VALUES ('test'); RAISERROR('Insert failed!', 16, 1);",
				{},
				{ datasource: ds }
			);
		} catch ( any e ) {
			exceptionMessage = e.message;
		}
		expect( exceptionMessage ).toBe( arguments.expectedMessage );
	}

	private function runRaiserrorMultipleStatements( required boolean modern, required string expectedMessage ) {
		setMSSQLModern( arguments.modern );
		var ds = getJtdsDatasource();
		var exceptionMessage = "[no exception found]";
		try {
			queryExecute(
				"
				DECLARE @test TABLE (id INT PRIMARY KEY)
				INSERT INTO @test (id) VALUES (2), (3), (1)
				RAISERROR('Multi-statement error!', 16, 1);
				SELECT id FROM @test ORDER BY id ASC
				",
				{},
				{ datasource: ds }
			);
		} catch ( any e ) {
			exceptionMessage = e.message;
		}
		expect( exceptionMessage ).toBe( arguments.expectedMessage );
	}

	private struct function getCredentials() {
		return server._getSystemPropOrEnvVars( "SERVER, USERNAME, PASSWORD, PORT, DATABASE", "MSSQL_" );
	}

	private struct function getJtdsDatasource() {
		var c = getCredentials();
		return {
			class: "net.sourceforge.jtds.jdbc.Driver",
			maven: "net.sourceforge.jtds:jtds:1.3.1",
			connectionString: "jdbc:jtds:sqlserver://#c.SERVER#:#c.PORT#/#c.DATABASE#",
			username: c.USERNAME,
			password: c.PASSWORD,
			blob: true,
			clob: true,
			validate: false
		};
	}

}
