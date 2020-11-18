BEGIN

	-- SCRIPT VARIABLES DECLARATION
	DECLARE @rowcountmax BIGINT
	DECLARE @rowcountmin INT
	DECLARE @string2search VARCHAR(20)
	DECLARE @tableid VARCHAR(500)
	DECLARE @tablename VARCHAR(500)
	DECLARE @columname VARCHAR(500)
	DECLARE @schemaname VARCHAR(500)
	DECLARE @cmd nvarchar(4000)
	DECLARE @SQLCommand VARCHAR(2000)
	DECLARE @total INT
	DECLARE @counter INT

	--BEGIN SCRIPT CONFIG
			-- string to find in all database
			SET @string2search = 'string to search'

			--Example
			SET @string2search = 'Engineer'
			
			-- limit the tables by the row count
			-- WARNING: if you don´t want this limitation, you must comment the lines where this variables are used.
																		--AND ddps.row_count >= @rowcountmin 
																		--AND ddps.row_count <= @rowcountmax
			SET @rowcountmax = 10000
			SET @rowcountmin = 1
	--END SCRIPT CONFIG
	

	-- temporary table
	IF OBJECT_ID('tempdb..#searchqueries') IS NOT NULL DROP TABLE #searchqueries	
	CREATE TABLE #searchqueries (
		TableID VARCHAR(200),
		Tablename VARCHAR(200),
		ColumnName VARCHAR(200),
		SchemaName VARCHAR(200),
		ColumnKey VARCHAR(200),
		SQLCommand VARCHAR(2000),
	)
	
	--prepare value to search, all upper with no spaces
	SET @string2search = UPPER(LTRIM(RTRIM(@string2search)))
	
	--cursor por iterate database tables and columns
	DECLARE tablescolumnscursor CURSOR FOR
	
	-- select all tables ot the database, with all of its fields
	SELECT DISTINCT
		 t.[object_id] AS TableID
		,t.name AS TableName		
		,c.name AS ColumnName
		,sch.name AS SchemaName
	FROM sys.tables t
		JOIN sys.dm_db_partition_stats AS ddps ON ddps.OBJECT_ID = t.OBJECT_ID
			AND ddps.row_count >= @rowcountmin 
			AND ddps.row_count <= @rowcountmax
		JOIN sys.columns c ON c.object_id = t.object_id
		JOIN sys.types s_t ON s_t.user_type_id = c.system_type_id
		JOIN sys.schemas sch ON sch.schema_id = t.schema_id
	WHERE 
		c.name NOT IN ('timestamp')	-- exclude timestamp fields
				
		-- exclude numeric type fields 
		--if you want include this fields in the search, just comment.
		AND c.system_type_id NOT IN (
				 56 --int
				,48 --tinyint
				,127--bigint
				,61 --datetime
				,106--decimal
				,36 --uniqueidentifier
				,34 --image
				)	

		-- table name filter.
		--and t.name like '%table name filter%'

		--column name filter
		--and c.name like '%column name filter%'


	ORDER BY t.name, c.name 

	OPEN tablescolumnscursor
	SET @total = @@CURSOR_ROWS	
	SET @counter = 0
	FETCH NEXT FROM tablescolumnscursor 
	INTO @tableid,@tablename,@columname,@schemaname
	--for each field
	WHILE @@FETCH_STATUS = 0
		BEGIN
			-- counter of processed fields
			SET @counter = @counter + 1
			-- verbose 
			PRINT @tablename + ' ' + @columname + '    '  + CAST(@counter AS VARCHAR) + '/' + CAST(@total AS VARCHAR)
			
			-- create select comand to help user with the match
			SET  @SQLCommand = 'SELECT [' + @columname + '],* FROM ['+ @schemaname +'].[' + @tablename + '] WHERE UPPER(LTRIM(RTRIM(CAST([' + @columname + '] AS VARCHAR(MAX))))) LIKE ''''%' + @string2search + '%'''''
			
			-- command to execute the search. with a positive match, insert a record in temporary table with table, field and query.
			SET @cmd = '
			IF (SELECT COUNT(*) FROM ['+ @schemaname +'].[' + @tablename + '] WHERE UPPER(LTRIM(RTRIM(CAST([' + @columname + '] AS VARCHAR(MAX))))) LIKE ''%' + @string2search + '%'') > 0 BEGIN
				INSERT #searchqueries (TableID,Tablename,ColumnName,SchemaName,ColumnKey,SQLCommand) VALUES (''' + @tableid + ''',''' + @tablename + ''',''' + @columname + ''',''' + @schemaname + ''',''' + ''','''+ @SQLCommand + ''')
			END
			'				
			--PRINT @SQLCommand
			--PRINT @cmd
			EXEC sp_executesql @cmd		

			FETCH NEXT FROM tablescolumnscursor 
			INTO @tableid,@tablename,@columname,@schemaname
		END

	CLOSE tablescolumnscursor
	DEALLOCATE tablescolumnscursor

	--select to show the result
	SELECT DISTINCT SchemaName,Tablename,ColumnName,SQLCommand FROM #searchqueries

	--delete temporary table
	IF OBJECT_ID('tempdb..#searchqueries') IS NOT NULL DROP TABLE #searchqueries
END

