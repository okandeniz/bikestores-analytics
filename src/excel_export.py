from pathlib import Path

import pandas as pd

from src.database import create_db_engine
from src.config import PROJECT_ROOT


# ============================================================
# Configuration
# ============================================================

OUTPUT_DIR = PROJECT_ROOT / "outputs" / "excel"
OUTPUT_FILE = OUTPUT_DIR / "BikeStores_Data.xlsx"


# ============================================================
# SQL queries
# ============================================================

QUERIES = {
    "Data_OrderItems": """
        SELECT *
        FROM vw_excel_order_items
        ORDER BY order_date, order_id, item_id;
    """,

    "Data_Orders": """
        SELECT *
        FROM vw_excel_orders
        ORDER BY order_date, order_id;
    """,

    "Data_Inventory": """
        SELECT *
        FROM vw_excel_inventory
        ORDER BY store_id, category_name, brand_name, product_id;
    """,
}


# ============================================================
# Load data
# ============================================================

def load_excel_data(engine):
    dataframes = {}

    for sheet_name, query in QUERIES.items():
        print(f"Loading {sheet_name}...")

        df = pd.read_sql_query(
            query,
            engine,
            coerce_float=True,
        )

        dataframes[sheet_name] = df

        print(
            f"{sheet_name}: "
            f"{len(df):,} rows × {len(df.columns)} columns"
        )

    return dataframes


# ============================================================
# Data type preparation
# ============================================================

def prepare_data_types(dataframes):
    date_columns = {
        "Data_OrderItems": [
            "order_date",
            "month_start",
            "required_date",
            "shipped_date",
        ],
        "Data_Orders": [
            "order_date",
            "month_start",
            "required_date",
            "shipped_date",
        ],
        "Data_Inventory": [],
    }

    for sheet_name, columns in date_columns.items():

        df = dataframes[sheet_name]

        for column in columns:
            if column in df.columns:
                df[column] = pd.to_datetime(
                    df[column],
                    errors="coerce",
                )

    return dataframes


# ============================================================
# Validation
# ============================================================

def validate_data(dataframes):
    order_items = dataframes["Data_OrderItems"]
    orders = dataframes["Data_Orders"]
    inventory = dataframes["Data_Inventory"]

    # --------------------------------------------------------
    # Grain checks
    # --------------------------------------------------------

    unique_order_items = (
        order_items[["order_id", "item_id"]]
        .drop_duplicates()
        .shape[0]
    )

    if len(order_items) != unique_order_items:
        raise ValueError(
            "Data_OrderItems grain validation failed."
        )

    unique_orders = orders["order_id"].nunique()

    if len(orders) != unique_orders:
        raise ValueError(
            "Data_Orders grain validation failed."
        )

    unique_inventory = (
        inventory[["store_id", "product_id"]]
        .drop_duplicates()
        .shape[0]
    )

    if len(inventory) != unique_inventory:
        raise ValueError(
            "Data_Inventory grain validation failed."
        )

    # --------------------------------------------------------
    # Sales reconciliation
    # --------------------------------------------------------

    item_sales = order_items[
        "realized_net_sales"
    ].sum()

    order_sales = orders[
        "realized_order_value"
    ].sum()

    if abs(item_sales - order_sales) > 0.01:
        raise ValueError(
            "Sales reconciliation failed between "
            "Data_OrderItems and Data_Orders."
        )

    # --------------------------------------------------------
    # Validation summary
    # --------------------------------------------------------

    print("\nValidation completed successfully.")
    print("-" * 50)

    print(
        f"Order Items : {len(order_items):,}"
    )

    print(
        f"Orders      : {len(orders):,}"
    )

    print(
        f"Inventory   : {len(inventory):,}"
    )

    print(
        f"Net Sales   : {item_sales:,.2f}"
    )

    print(
        "Stock Units : "
        f"{inventory['current_stock'].sum():,.0f}"
    )


# ============================================================
# Excel formatting
# ============================================================

def format_worksheet(
    workbook,
    worksheet,
    df,
    table_name,
):
    rows, cols = df.shape

    # --------------------------------------------------------
    # Formats
    # --------------------------------------------------------

    header_format = workbook.add_format(
        {
            "bold": True,
            "font_color": "#FFFFFF",
            "bg_color": "#1F4E78",
            "border": 1,
            "align": "center",
            "valign": "vcenter",
        }
    )

    currency_format = workbook.add_format(
        {
            "num_format": '#,##0.00',
        }
    )

    integer_format = workbook.add_format(
        {
            "num_format": '#,##0',
        }
    )

    decimal_format = workbook.add_format(
        {
            "num_format": '0.00',
        }
    )

    percentage_format = workbook.add_format(
        {
            "num_format": '0.00%',
        }
    )

    percentage_point_format = workbook.add_format(
        {
            "num_format": '0.00"%"',
        }
    )

    date_format = workbook.add_format(
        {
            "num_format": "yyyy-mm-dd",
        }
    )

    # --------------------------------------------------------
    # Excel Table
    # --------------------------------------------------------

    worksheet.add_table(
        0,
        0,
        rows,
        cols - 1,
        {
            "name": table_name,
            "style": "Table Style Medium 2",
            "columns": [
                {
                    "header": column,
                    "header_format": header_format,
                }
                for column in df.columns
            ],
        },
    )

    # --------------------------------------------------------
    # Freeze panes
    # --------------------------------------------------------

    worksheet.freeze_panes(1, 2)

    # --------------------------------------------------------
    # Column formatting
    # --------------------------------------------------------

    currency_columns = {
        "item_list_price",
        "gross_sales",
        "discount_amount",
        "net_sales",
        "realized_gross_sales",
        "realized_discount_amount",
        "realized_net_sales",
        "gross_order_value",
        "net_order_value",
        "realized_order_value",
        "realized_gross_order_value",
        "net_sales_12m",
    }

    integer_columns = {
        "order_id",
        "item_id",
        "report_year",
        "report_quarter",
        "month_number",
        "order_status",
        "is_completed",
        "store_id",
        "staff_id",
        "customer_id",
        "category_id",
        "brand_id",
        "product_id",
        "model_year",
        "quantity",
        "realized_units_sold",
        "line_item_count",
        "distinct_products",
        "total_units",
        "required_lead_days",
        "shipping_days",
        "is_late",
        "delay_days",
        "current_stock",
        "units_sold_12m",
        "orders_12m",
        "active_sales_months",
    }

    decimal_columns = {
        "effective_discount_pct",
        "avg_monthly_units_12m",
        "avg_units_per_active_month",
        "stock_coverage_months",
    }

    date_columns = {
        "order_date",
        "month_start",
        "required_date",
        "shipped_date",
    }

    for col_idx, column in enumerate(df.columns):

        sample = df[column].head(300)

        max_value_length = sample.map(
            lambda value: (
                len(str(value))
                if pd.notna(value)
                else 0
            )
        ).max()

        width = min(
            max(
                len(str(column)) + 2,
                int(max_value_length) + 2,
            ),
            32,
        )

        cell_format = None

        if column in currency_columns:
            cell_format = currency_format

        elif column == "discount":
            cell_format = percentage_format

        elif (
            column.endswith("_pct")
            or column == "discount_pct"
        ):
            cell_format = percentage_point_format

        elif column in integer_columns:
            cell_format = integer_format

        elif column in decimal_columns:
            cell_format = decimal_format

        elif column in date_columns:
            cell_format = date_format
            width = 13

        worksheet.set_column(
            col_idx,
            col_idx,
            width,
            cell_format,
        )


# ============================================================
# Export Excel
# ============================================================

def export_excel(dataframes):
    OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    print(
        f"\nCreating Excel workbook:\n{OUTPUT_FILE}"
    )

    with pd.ExcelWriter(
        OUTPUT_FILE,
        engine="xlsxwriter",
        datetime_format="yyyy-mm-dd",
        date_format="yyyy-mm-dd",
    ) as writer:

        workbook = writer.book

        table_names = {
            "Data_OrderItems": "tblOrderItems",
            "Data_Orders": "tblOrders",
            "Data_Inventory": "tblInventory",
        }

        for sheet_name, df in dataframes.items():

            df.to_excel(
                writer,
                sheet_name=sheet_name,
                index=False,
            )

            worksheet = writer.sheets[
                sheet_name
            ]

            format_worksheet(
                workbook=workbook,
                worksheet=worksheet,
                df=df,
                table_name=table_names[
                    sheet_name
                ],
            )

    print("\nExcel export completed.")


# ============================================================
# Main
# ============================================================

def main():
    engine = create_db_engine()

    try:
        dataframes = load_excel_data(
            engine
        )

        dataframes = prepare_data_types(
            dataframes
        )

        validate_data(
            dataframes
        )

        export_excel(
            dataframes
        )

    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
