
locals{
    ssm_ps = {
        1 = {
            name                = "/example/endpoint",
            value_dbinstance    = aws_db_instance.mysql_db.address
        },
        2 = {
            name                = "/example/username",
            value_dbinstance    = aws_db_instance.mysql_db.username
        },
        3 = {
            name                = "/example/password",
            value_dbinstance    = aws_db_instance.mysql_db.password
        },
        4 = {
            name                = "/example/database",
            value_dbinstance    = aws_db_instance.mysql_db.db_name
        }    
    }
}