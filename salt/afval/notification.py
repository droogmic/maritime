import datetime as dt
import locale
import requests
import subprocess

from bs4 import BeautifulSoup
from contextlib import contextmanager

def url(postcode: str, housenumber: str) -> str:
    return f"https://www.mijnafvalwijzer.nl/en/{postcode}/{housenumber}/"

@contextmanager
def override_locale(category, locale_string):
    prev_locale_string = locale.getlocale(category)
    locale.setlocale(category, locale_string)
    yield
    locale.setlocale(category, prev_locale_string)


def parse_date_nl(date_str_nl: str):
    if date_str_nl.lower() == "vandaag":
        return dt.date.today()
    with override_locale(locale.LC_TIME, "nl_NL.UTF-8"):
        first_month_day = dt.datetime.strptime(date_str_nl, "%A %d %B")
        year = dt.date.today().year
        if dt.date.today().month == "12" and first_month_day.month == "1":  # New Year
            year += 1
        first_date = dt.date(year, first_month_day.month, first_month_day.day)
    return first_date


def send_notification(summary: str, body: str = "", urgent: bool = True):
    subprocess.run(
        [
            "/usr/bin/notify-send",
            "--icon=entry-delete",
            "--app-name=Afvalkalendar",
            f"--urgency={'critical' if urgent else 'normal'}",
            "--expire-time=10000",
            summary,
            body,
        ]
    )


def parse_collection_day_spans(collection_day_spans):
    date_span, type_span = collection_day_spans
    return CollectionDay(date_span.string, type_span.string)


class CollectionDay:
    date: dt.date
    type: str

    def __init__(self, date_nl, type):
        self.date = parse_date_nl(date_nl)
        self.type = type

    def __repr__(self):
        return f"{self.date.isoformat()} {self.type}"

    def __lt__(lhs, rhs):
        return lhs.date.__lt__(rhs.date)


def main():

    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("postcode")
    parser.add_argument("housenumber")
    args = parser.parse_args()


    response = requests.get(url(args.postcode, args.housenumber))
    soup = BeautifulSoup(response.text, "html.parser")

    first_collection_day_div = soup.find("div", class_="firstcollectionday")
    first_type_nl = first_collection_day_div.find("p", class_="firstWasteType").string
    first_date_nl = first_collection_day_div.find("p", class_="firstDate").string
    next_collection = CollectionDay(first_date_nl, first_type_nl)

    collection_days_div = soup.find("div", class_="ophaaldagen")

    collection_days = sorted(
        [
            parse_collection_day_spans(collection_day_p.find_all("span"))
            for collection_day_p in collection_days_div.find_all("p")
        ]
    )
    future_collections = [cd for cd in collection_days if cd.date > dt.date.today()]

    if next_collection.date != future_collections[0].date and next_collection.date != dt.date.today():
        send_notification("Script Error")
        raise Exception(f"{next_collection}, {future_collections}")

    if (next_collection.date - dt.date.today()) < dt.timedelta(days=2):
        summary = f"Upcoming: {next_collection.type}"
        if next_collection.date == dt.date.today():
            summary = f"Today: {next_collection.type}"
        body = "\n".join([str(cd) for cd in future_collections[:3]])
        send_notification(summary, body)


if __name__ == "__main__":
    main()