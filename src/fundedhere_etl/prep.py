"""CSV preprocessing - consolidates 4 prep_*.py scripts into single module"""

import csv
import re
from pathlib import Path
from typing import Dict, List

from . import logger
from .config import Settings


def normalize_column(s: str | None) -> str:
    """
    Normalize column name for fuzzy matching.

    Converts "Beneficiary Bank Account Number" → "beneficiary bank account number"
    """
    s = (s or "").strip().lower()
    s = re.sub(r'[^a-z0-9]+', ' ', s)
    s = re.sub(r'\s+', ' ', s)
    return s.strip()


# Central column mapping registry (replaces duplicated CANON + ALIASES in 4 scripts)
TABLE_SCHEMAS = {
    "external_accounts": {
        "pattern": "external_accounts_[0-9]*.csv",  # Match date-stamped source files
        "canonical": [
            "beneficiary_bank_account_number",
            "buy_amount",
            "buy_currency",
            "created_date",
        ],
        "aliases": {
            "beneficiary_bank_account_number": [
                "beneficiary bank account number",
                "beneficiary bank account no",
                "beneficiary account number",
                "bank account number",
                "receiver bank account number",
                "receiver virtual account number",
                "receiver va number",
            ],
            "buy_amount": [
                "buy amount",
                "amount",
                "total amount",
                "pull amount",
            ],
            "buy_currency": [
                "buy currency",
                "currency",
                "buy ccy",
                "ccy",
            ],
            "created_date": [
                "created date",
                "transaction date",
                "completed date",
                "value date",
                "date",
            ],
        },
    },
    "va_txn": {
        "pattern": "va_txn_[0-9]*.csv",  # Match date-stamped source files
        "canonical": [
            "sender_virtual_account_id",
            "sender_virtual_account_number",
            "sender_note_id",
            "receiver_virtual_account_id",
            "receiver_virtual_account_number",
            "receiver_note_id",
            "receiver_va_opening_balance",
            "receiver_va_closing_balance",
            "amount",
            "date",
            "remarks",
        ],
        "aliases": {
            "sender_virtual_account_id": ["sender virtual account id", "sender va id"],
            "sender_virtual_account_number": [
                "sender virtual account number",
                "sender va number",
                "sender bank account number",
                "sender account number",
            ],
            "sender_note_id": [
                "sender note id",
                "sender ref id",
                "sender reference id",
                "sender note",
            ],
            "receiver_virtual_account_id": [
                "receiver virtual account id",
                "receiver va id",
            ],
            "receiver_virtual_account_number": [
                "receiver virtual account number",
                "receiver va number",
                "receiver bank account number",
                "receiver account number",
            ],
            "receiver_note_id": [
                "receiver note id",
                "receiver ref id",
                "receiver reference id",
                "receiver note",
            ],
            "receiver_va_opening_balance": [
                "receiver va opening balance",
                "opening balance",
            ],
            "receiver_va_closing_balance": [
                "receiver va closing balance",
                "closing balance",
            ],
            "amount": ["amount", "transaction amount"],
            "date": ["date", "transaction date", "created date"],
            "remarks": ["remarks", "description", "note"],
        },
    },
    "repmt_sku": {
        "pattern": "repmt_sku_[0-9]*.csv",  # Match date-stamped source files
        "canonical": [
            "merchant",
            "sku_id",
            "acquirer_fees_expected",
            "acquirer_fees_paid",
            "fh_admin_fees_expected",
            "fh_admin_fees_paid",
            "int_difference_expected",
            "int_difference_paid",
            "sr_principal_expected",
            "sr_principal_paid",
            "sr_interest_expected",
            "sr_interest_paid",
            "jr_principal_expected",
            "jr_principal_paid",
            "jr_interest_expected",
            "jr_interest_paid",
            "spar_merchant",
            "additional_interests_paid_to_fh",
        ],
        "aliases": {
            "merchant": ["merchant", "merchant name", "spar merchant"],
            "sku_id": ["sku id", "sku", "note id"],
            # Most columns match exactly, minimal aliases needed
        },
    },
    "repmt_sales": {
        "pattern": "repmt_sales_[0-9]*.csv",  # Match date-stamped source files
        "canonical": [
            "merchant",
            "sku_id",
            "total_funds_inflow",
            "sales_proceeds",
            "l2e",
        ],
        "aliases": {
            "merchant": ["merchant", "merchant name"],
            "sku_id": ["sku id", "sku", "note id"],
            "total_funds_inflow": [
                "total funds inflow",
                "total inflow",
                "fund inflow",
                "funds inflow",
            ],
            "sales_proceeds": ["sales proceeds", "sales proceed", "proceeds"],
            "l2e": ["l2 e", "l2e", "layer 2 entity"],
        },
    },
}


class CSVPreprocessor:
    """
    Unified CSV preprocessor for all 4 tables.

    Replaces:
    - scripts/prep_external.py (76 lines)
    - scripts/prep_vatxn.py (116 lines)
    - scripts/prep_repmt_sku.py (146 lines)
    - scripts/prep_repmt_sales.py (74 lines)
    Total: 412 lines → ~200 lines (50% reduction)
    """

    def __init__(self, settings: Settings):
        self.settings = settings
        self.data_dir = Path(settings.inc_data_dir)

    def find_csv(self, pattern: str) -> Path:
        """Find newest CSV file matching pattern"""
        files = sorted(self.data_dir.glob(pattern))
        if not files:
            raise FileNotFoundError(
                f"No CSV file found matching pattern: {pattern} in {self.data_dir}"
            )
        return files[-1]

    def build_column_map(
        self, headers: List[str], canonical: List[str], aliases: Dict[str, List[str]]
    ) -> Dict[str, str | None]:
        """
        Map canonical column names to actual CSV column names.

        Returns:
            {canonical_name: actual_csv_column_name}
        """
        # Normalize all headers for fuzzy matching
        header_map = {normalize_column(h): h for h in headers}

        colmap = {}
        missing = []

        for canon_col in canonical:
            found = None

            # Try aliases first
            for alias in aliases.get(canon_col, []):
                if normalize_column(alias) in header_map:
                    found = header_map[normalize_column(alias)]
                    break

            # Fallback to exact match
            if not found and normalize_column(canon_col) in header_map:
                found = header_map[normalize_column(canon_col)]

            if not found:
                missing.append(canon_col)

            colmap[canon_col] = found

        if missing:
            raise ValueError(
                f"Missing required columns: {missing}\n"
                f"Found headers: {headers}\n"
                f"Normalized: {[normalize_column(h) for h in headers]}"
            )

        return colmap

    def process_table(self, table_name: str) -> Path:
        """
        Process a single table's CSV file.

        Args:
            table_name: One of: external_accounts, va_txn, repmt_sku, repmt_sales

        Returns:
            Path to output CSV file
        """
        schema = TABLE_SCHEMAS[table_name]

        # Find input CSV
        input_file = self.find_csv(schema["pattern"])
        output_file = self.data_dir / f"{table_name}_prepped.csv"

        logger.info(
            "Processing CSV",
            table=table_name,
            input=str(input_file.name),
            output=str(output_file.name),
        )

        # Read, normalize, write
        with open(input_file, "r", newline="", encoding="utf-8-sig") as inf:
            reader = csv.DictReader(inf)
            headers = reader.fieldnames or []

            # Build column mapping
            colmap = self.build_column_map(
                headers, schema["canonical"], schema["aliases"]
            )

            # Write normalized CSV
            with open(output_file, "w", newline="", encoding="utf-8") as outf:
                writer = csv.writer(outf)
                writer.writerow(schema["canonical"])

                for row in reader:
                    writer.writerow([row.get(colmap[col], "") for col in schema["canonical"]])

        logger.info("CSV processed", table=table_name, output=str(output_file))
        return output_file

    def process_all(self) -> Dict[str, Path]:
        """
        Process all 4 CSV files.

        Returns:
            Dict of {table_name: output_path}
        """
        logger.info("Starting CSV preprocessing", table_count=len(TABLE_SCHEMAS))

        results = {}
        for table_name in TABLE_SCHEMAS:
            results[table_name] = self.process_table(table_name)

        logger.info("CSV preprocessing complete", processed=len(results))
        return results
