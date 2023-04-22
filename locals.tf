
locals{
    ssm_ps = [
        {
            name                = "/example/endpoint",
            value_dbinstance    = aws_db_instance.mysql_db.address
        },
        {
            name                = "/example/username",
            value_dbinstance    = aws_db_instance.mysql_db.username
        },
        {
            name                = "/example/password",
            value_dbinstance    = aws_db_instance.mysql_db.password
        },
        {
            name                = "/example/database",
            value_dbinstance    = aws_db_instance.mysql_db.db_name
        }    
    ]
}