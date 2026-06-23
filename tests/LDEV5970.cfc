/**
 * Based on https://luceeserver.atlassian.net/browse/LDEV-5970
 * Tests MSSQL modern mode with parameterized queries and identity column results.
 * Adapted to use the jTDS driver explicitly.
 * Requires Lucee 7+ (useMSSQLModern field was added in Lucee 7).
 */
component extends="org.lucee.cfml.test.LuceeTestCase" labels="jtds" {

	variables.tableName = "ldev5970_test";

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

		describe( "LDEV-5970: MSSQL modern mode with jTDS driver", function() {

			describe( "SELECT parameterized with result attribute", function() {
				it( title="modern=false", skip=isNotSupported(), body=function() {
					runParameterizedSelectWithResult( modern=false );
				});
				it( title="modern=true", skip=isNotSupported(), body=function() {
					runParameterizedSelectWithResult( modern=true );
				});
			});

			describe( "SELECT simple with result attribute", function() {
				it( title="modern=false", skip=isNotSupported(), body=function() {
					runSimpleSelectWithResult( modern=false );
				});
				it( title="modern=true", skip=isNotSupported(), body=function() {
					runSimpleSelectWithResult( modern=true );
				});
			});

			describe( "SELECT parameterized without result attribute", function() {
				it( title="modern=false", skip=isNotSupported(), body=function() {
					runParameterizedSelectNoResult( modern=false );
				});
				it( title="modern=true", skip=isNotSupported(), body=function() {
					runParameterizedSelectNoResult( modern=true );
				});
			});

			describe( "INSERT with identity key", function() {
				it( title="modern=false", skip=isNotSupported(), body=function() {
					runInsertWithGeneratedKey( modern=false );
				});
				it( title="modern=true", skip=isNotSupported(), body=function() {
					runInsertWithGeneratedKey( modern=true );
				});
			});

			describe( "INSERT parameterized with identity key", function() {
				it( title="modern=false", skip=isNotSupported(), body=function() {
					runParameterizedInsertWithGeneratedKey( modern=false );
				});
				it( title="modern=true", skip=isNotSupported(), body=function() {
					runParameterizedInsertWithGeneratedKey( modern=true );
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

	private function runParameterizedSelectWithResult( required boolean modern ) {
		setMSSQLModern( arguments.modern );
		var ds = getJtdsDatasource();
		var result = queryExecute(
			"SELECT TOP 10 name FROM sys.objects WHERE object_id > :objectId",
			{ objectId: { value: 1, cfsqltype: "CF_SQL_INTEGER" } },
			{ datasource: ds, result: "local.queryResult" }
		);
		expect( result ).toBeQuery();
		expect( result.recordCount ).toBeGTE( 0 );
		expect( local.queryResult ).toBeStruct();
		expect( local.queryResult ).toHaveKey( "recordcount" );
	}

	private function runSimpleSelectWithResult( required boolean modern ) {
		setMSSQLModern( arguments.modern );
		var ds = getJtdsDatasource();
		var result = queryExecute(
			"SELECT TOP 5 name FROM sys.objects",
			{},
			{ datasource: ds, result: "local.queryResult" }
		);
		expect( result ).toBeQuery();
		expect( result.recordCount ).toBeGTE( 0 );
		expect( local.queryResult ).toBeStruct();
	}

	private function runParameterizedSelectNoResult( required boolean modern ) {
		setMSSQLModern( arguments.modern );
		var ds = getJtdsDatasource();
		var result = queryExecute(
			"SELECT TOP 10 name FROM sys.objects WHERE object_id > :objectId",
			{ objectId: { value: 1, cfsqltype: "CF_SQL_INTEGER" } },
			{ datasource: ds }
		);
		expect( result ).toBeQuery();
		expect( result.recordCount ).toBeGTE( 0 );
	}

	private function runInsertWithGeneratedKey( required boolean modern ) {
		setMSSQLModern( arguments.modern );
		createTestTable();
		var ds = getJtdsDatasource();
		queryExecute(
			"INSERT INTO #variables.tableName# (name) VALUES ('test')",
			{},
			{ datasource: ds, result: "local.queryResult" }
		);
		expect( local.queryResult ).toBeStruct();
		expect( local.queryResult ).toHaveKey( "generatedKey" );
		expect( local.queryResult.generatedKey ).toBeNumeric();
		expect( local.queryResult.generatedKey ).toBeGTE( 1 );
	}

	private function runParameterizedInsertWithGeneratedKey( required boolean modern ) {
		setMSSQLModern( arguments.modern );
		createTestTable();
		var ds = getJtdsDatasource();
		queryExecute(
			"INSERT INTO #variables.tableName# (name) VALUES (:name)",
			{ name: { value: "test param", cfsqltype: "CF_SQL_VARCHAR" } },
			{ datasource: ds, result: "local.queryResult" }
		);
		expect( local.queryResult ).toBeStruct();
		expect( local.queryResult ).toHaveKey( "generatedKey" );
		expect( local.queryResult.generatedKey ).toBeNumeric();
		expect( local.queryResult.generatedKey ).toBeGTE( 1 );
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
