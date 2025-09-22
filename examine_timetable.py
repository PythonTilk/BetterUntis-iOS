import os
from pathlib import Path

import webuntis
from datetime import datetime, timedelta
import json


def load_env() -> None:
    search_paths = [Path.cwd(), Path(__file__).resolve().parent]
    for start in search_paths:
        for candidate in [start] + list(start.parents):
            env_file = candidate / ".env"
            if env_file.exists():
                for raw_line in env_file.read_text(encoding="utf-8").splitlines():
                    line = raw_line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if "=" not in line:
                        continue
                    key, value = line.split("=", 1)
                    os.environ.setdefault(key.strip(), value.strip())
                return


def require_env(key: str) -> str:
    value = os.environ.get(key, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable '{key}'. Create a .env file based on .env.example before running this script.")
    return value


load_env()

server = require_env("UNTIS_BASE_SERVER").replace("https://", "").replace("http://", "")
school = require_env("UNTIS_SCHOOL").replace(" ", "+")
username = require_env("UNTIS_USERNAME")
password = require_env("UNTIS_PASSWORD")

try:
    with webuntis.Session(
        username=username,
        password=password,
        server=server,
        school=school,
        useragent='BetterUntis-Test'
    ).login() as s:
        
        print("✅ Logged in successfully!")
        
        # Get my timetable and examine structure
        print("\n📅 Examining my_timetable structure...")
        start = datetime.now() - timedelta(days=7)
        end = datetime.now() + timedelta(days=14)
        
        try:
            my_tt = s.my_timetable(start=start, end=end)
            print(f"✅ My timetable: {len(my_tt)} periods found")
            
            if my_tt:
                # Examine the first few periods
                for i, period in enumerate(my_tt[:3]):
                    print(f"\n📋 Period {i+1} attributes:")
                    for attr in dir(period):
                        if not attr.startswith('_'):
                            try:
                                value = getattr(period, attr)
                                print(f"   {attr}: {value}")
                            except:
                                print(f"   {attr}: <cannot access>")
                
                # Look for any periods that might have status indicators
                print(f"\n🔍 Searching for status/absence indicators in all {len(my_tt)} periods...")
                
                status_found = []
                code_found = []
                cancelled_found = []
                
                for i, period in enumerate(my_tt):
                    # Check for various absence-related attributes
                    for attr in ['status', 'lstext', 'activityType', 'code', 'cancelled', 'substituted']:
                        if hasattr(period, attr):
                            value = getattr(period, attr)
                            if value and str(value).strip():
                                print(f"   Period {i}: {attr} = {value}")
                                if 'status' in attr.lower():
                                    status_found.append((i, value))
                                elif 'code' in attr.lower():
                                    code_found.append((i, value))
                
                print(f"\n📊 Summary:")
                print(f"   - Periods with status: {len(status_found)}")
                print(f"   - Periods with codes: {len(code_found)}")
                
        except Exception as e:
            print(f"❌ Timetable examination failed: {e}")
            import traceback
            traceback.print_exc()
        
        # Test if we can access extended timetable data
        print("\n🔍 Testing timetable_extended...")
        try:
            tt_ext = s.timetable_extended(start=start, end=end, student=None)
            print(f"✅ Extended timetable: {len(tt_ext)} periods found")
        except Exception as e:
            print(f"❌ Extended timetable: {e}")
            
        # Check substitutions - this might contain absence info
        print("\n🔄 Testing substitutions...")
        try:
            today = datetime.now().date()
            subs = s.substitutions(today)
            print(f"✅ Substitutions: {len(subs)} found")
            if subs:
                print(f"   Sample substitution: {subs[0]}")
        except Exception as e:
            print(f"❌ Substitutions: {e}")

except Exception as e:
    print(f"❌ Connection failed: {e}")
    import traceback
    traceback.print_exc()
