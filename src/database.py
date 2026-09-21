from sqlalchemy import create_engine
from sqlalchemy.engine import URL

from src.config import (
    DB_HOST,
    DB_PORT,
    DB_USER,
    DB_PASSWORD,
    DB_NAME,
)


def create_db_engine():
    connection_url = URL.create(
        "mysql+pymysql",
        username=DB_USER,
        password=DB_PASSWORD,
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
    )

    return create_engine(
        connection_url,
        pool_pre_ping=True,
    )
