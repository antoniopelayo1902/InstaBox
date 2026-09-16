"""Acceso a la base de datos RDS PostgreSQL.

Abre una conexion por operacion usando las credenciales leidas de
Secrets Manager. Para la carga de esta practica es mas que suficiente.
"""

from contextlib import contextmanager

import psycopg2
from psycopg2.extras import RealDictCursor

from .secrets import get_db_secret


def _connect():
    s = get_db_secret()
    return psycopg2.connect(
        host=s["host"],
        port=int(s.get("port", 5432)),
        dbname=s["dbname"],
        user=s["username"],
        password=s["password"],
        connect_timeout=10,
    )


@contextmanager
def get_conn():
    """Context manager que hace commit al salir bien y rollback si hay error."""
    conn = _connect()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def dict_cursor(conn):
    """Cursor que regresa filas como diccionarios."""
    return conn.cursor(cursor_factory=RealDictCursor)
