CREATE OR ALTER PROCEDURE dwh.sp_HashCompare

    @tableName1 NVARCHAR(MAX),
    @schema1 NVARCHAR(MAX),
    @tableName2 NVARCHAR(MAX),
    @schema2 NVARCHAR(MAX)

/*
=========================================================================================
Overview
dwh.sp_HashCompare is a stored procedure that facilitates the comparison of two tables at the hash value level in SQL Server. 
It is primarily used to detect discrepancies between two tables by comparing the hash values of their rows.

Features
Compares two tables by generating MD5 hash values for each row.
Excludes certain columns like timestamps and metadata from the hash generation to focus on meaningful data.
Reports on hash value matches and mismatches, providing insights into data consistency between tables.
Includes row count comparisons for additional verification.

Parameters
@tableName1 NVARCHAR(MAX): Name of the first table to compare.
@schema1 NVARCHAR(MAX): Schema of the first table.
@tableName2 NVARCHAR(MAX): Name of the second table to compare.
@schema2 NVARCHAR(MAX): Schema of the second table.

Behavior
Generates dynamic SQL to create MD5 hashes of each row in both tables, excluding certain system or metadata columns.
Executes these queries and retrieves the number of rows in each table.
Constructs and executes a comparison query to identify rows with non-matching hash values.
Reports the comparison result, including the number of mismatched rows and the total row count for each table.
In case of an error, captures and raises the error details.

Example:

EXEC dwh.sp_HashCompare 
  @tableName1 = 'YourFirstTableName', 
  @schema1 = 'YourFirstTableSchema',
  @tableName2 = 'YourSecondTableName',
  @schema2 = 'YourSecondTableSchema';


Author         : Felipe C, 15 Dec 2023
========================================================================================= 
*/

AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY

    -- Construct the dynamic SQL query for the first table
	DECLARE @SQL1 NVARCHAR(MAX)
	DECLARE @RowCountSQL1 BIGINT
    DECLARE @CountSQL1 NVARCHAR(MAX)

    SET @SQL1 = '
        SELECT *,
        HASHBYTES(''MD5'', CONCAT(' + STUFF((SELECT ', ' + 'LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(' + QUOTENAME(c.name) + ', CHAR(10), CHAR(32)),CHAR(13), CHAR(32)),CHAR(160), CHAR(32)),CHAR(9),CHAR(32))))'
        FROM sys.columns c 
        WHERE c.object_id = OBJECT_ID(@schema1 + '.' + @tableName1) 
 --         AND c.name NOT LIKE '%Process_DateTime%'  Excludes certain columns like timestamps and metadata from the hash generation to focus on meaningful data
 --         AND c.name NOT LIKE '%CreatedDateTime%'
 --         AND c.name NOT LIKE '%Created_DateTime%'
 --         AND c.name NOT LIKE '%ModifiedDateTime%'
--			AND c.name NOT LIKE '%Modified_DateTime%'
--			AND c.name NOT LIKE '%DEFINITIONGROUP%'
--			AND c.name NOT LIKE '%EXECUTIONID%'
--			AND c.name NOT LIKE '%PARTITION%'
--			AND c.name NOT LIKE '%SYNCSTARTDATETIME%'
        FOR XML PATH('')), 1, 2, '') + ')) AS HASHBYTES1
    FROM ' + QUOTENAME(@schema1) + '.' + QUOTENAME(@tableName1);

	SET @CountSQL1 = 'SELECT @RowCountSQL2 = COUNT(*) FROM ' + QUOTENAME(@schema1) + '.' + QUOTENAME(@tableName1)
    EXEC sp_executesql @CountSQL1, N'@RowCountSQL2 BIGINT OUTPUT', @RowCountSQL1 OUTPUT

    -- Construct the dynamic SQL query for the second table
	DECLARE @SQL2 NVARCHAR(MAX)
	DECLARE @RowCountSQL2 BIGINT
    DECLARE @CountSQL2 NVARCHAR(MAX)

    SET @SQL2 = '
        SELECT *,
        HASHBYTES(''MD5'', CONCAT(' + STUFF((SELECT ', ' + 'LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(' + QUOTENAME(c.name) + ', CHAR(10), CHAR(32)),CHAR(13), CHAR(32)),CHAR(160), CHAR(32)),CHAR(9),CHAR(32))))'
        FROM sys.columns c 
        WHERE c.object_id = OBJECT_ID(@schema2 + '.' + @tableName2) 
 --         AND c.name NOT LIKE '%Process_DateTime%'  Excludes certain columns like timestamps and metadata from the hash generation to focus on meaningful data
 --         AND c.name NOT LIKE '%CreatedDateTime%'
 --         AND c.name NOT LIKE '%Created_DateTime%'
 --         AND c.name NOT LIKE '%ModifiedDateTime%'
--			AND c.name NOT LIKE '%Modified_DateTime%'
--			AND c.name NOT LIKE '%DEFINITIONGROUP%'
--			AND c.name NOT LIKE '%EXECUTIONID%'
--			AND c.name NOT LIKE '%PARTITION%'
--			AND c.name NOT LIKE '%SYNCSTARTDATETIME%'
        FOR XML PATH('')), 1, 2, '') + ')) AS HASHBYTES1
    FROM ' + QUOTENAME(@schema2) + '.' + QUOTENAME(@tableName2);

	SET @CountSQL2 = 'SELECT @RowCountSQL2 = COUNT(*) FROM ' + QUOTENAME(@schema2) + '.' + QUOTENAME(@tableName2)
    EXEC sp_executesql @CountSQL2, N'@RowCountSQL2 BIGINT OUTPUT', @RowCountSQL2 OUTPUT

     -- Create a dynamic SQL query to identify non-matching rows based on hasbytes
     DECLARE @ComparisonQuery NVARCHAR(MAX)
        SET @ComparisonQuery = '
            SELECT *, QUOTENAME(''' + @tableName1 + ''') AS TableName
            FROM (
                ' + @SQL1 + '
            ) AS A
            WHERE NOT EXISTS (
                SELECT 1
                FROM (
                    ' + @SQL2 + '
                ) AS B
                WHERE A.HASHBYTES1 = B.HASHBYTES1
            )
            UNION
            SELECT *, QUOTENAME(''' + @tableName2 + ''') AS TableName
            FROM (
                ' + @SQL2 + '
            ) AS B
            WHERE NOT EXISTS (
                SELECT 1
                FROM (
                    ' + @SQL1 + '
                ) AS A
                WHERE B.HASHBYTES1 = A.HASHBYTES1
            )
			ORDER BY 1
        '
     -- Execute the comparison query
     DECLARE @RowCount INT
         EXEC sp_executesql @ComparisonQuery
	     SET @RowCount = @@rowcount;

     -- Check if the result set is empty and print "Hash match" if true
     IF @RowCount = 0
     PRINT 'Hash values match between tables ' + QUOTENAME(@schema1) + '.' + QUOTENAME(@tableName1) + ' and ' + QUOTENAME(@schema2) + '.' + QUOTENAME(@tableName2) + CHAR(13) + CHAR(10) +
      'Number of records for table ' + QUOTENAME(@schema1) + '.' + QUOTENAME(@tableName1) + ' : ' + CAST(@RowCountSQL1 AS NVARCHAR(10)) + CHAR(13) + CHAR(10) +
      'Number of records for table ' + QUOTENAME(@schema2) + '.' + QUOTENAME(@tableName2) + ' : ' + CAST(@RowCountSQL2 AS NVARCHAR(10));
    ELSE 
     PRINT 'Hash values does not match between tables ' + QUOTENAME(@schema1) + '.' + QUOTENAME(@tableName1) + ' and ' + QUOTENAME(@schema2) + '.' + QUOTENAME(@tableName2) + CHAR(13) + CHAR(10) +
	  'Number of Hash mismatched records: ' + CAST(@RowCount AS NVARCHAR(10)) + CHAR(13) + CHAR(10) +
      'Number of records for table ' + QUOTENAME(@schema1) + '.' + QUOTENAME(@tableName1) + ' : ' + CAST(@RowCountSQL1 AS NVARCHAR(10)) + CHAR(13) + CHAR(10) +
      'Number of records for table ' + QUOTENAME(@schema2) + '.' + QUOTENAME(@tableName2) + ' : ' + CAST(@RowCountSQL2 AS NVARCHAR(10));

	 
	END TRY

	BEGIN CATCH

	DECLARE @ErrorMessage NVARCHAR(4000);
	DECLARE @ErrorSeverity INT;
	DECLARE @ErrorState INT;

	SELECT
		@ErrorMessage = ERROR_MESSAGE()
	   ,@ErrorSeverity = ERROR_SEVERITY()
	   ,@ErrorState = ERROR_STATE();

	RAISERROR (
	@ErrorMessage,
	@ErrorSeverity,
	@ErrorState
	);

END CATCH

END
