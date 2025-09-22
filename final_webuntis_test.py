import os
from pathlib import Path

import webuntis
from datetime import datetime, timedelta


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
        
        # Get current school year info to ensure proper date ranges
        try:
            schoolyears = s.schoolyears()
            current_year = [y for y in schoolyears if y.get('is_current', False)]
            if current_year:
                print(f"📅 Current school year: {current_year[0]}")
                start_date = datetime.strptime(current_year[0]['start_date'], '%Y-%m-%d').date()
                end_date = datetime.strptime(current_year[0]['end_date'], '%Y-%m-%d').date()
                print(f"   Range: {start_date} to {end_date}")
            else:
                print("⚠️ Using current dates within school year")
                start_date = datetime.now().date()
                end_date = start_date + timedelta(days=7)
        except Exception as e:
            print(f"❌ School year info: {e}")
            start_date = datetime.now().date()
            end_date = start_date + timedelta(days=7)
        
        # Test current week timetable
        print(f"\n📅 Getting timetable for {start_date} to {end_date}...")
        try:
            my_tt = s.my_timetable(start=start_date, end=end_date)
            print(f"✅ My timetable: {len(my_tt)} periods found")
            
            if my_tt:
                # Examine first period structure
                period = my_tt[0]
                print(f"\n📋 Period structure (first period):")
                attrs = ['id', 'date', 'starttime', 'endtime', 'klassen', 'teachers', 'subjects', 'rooms', 'lstext', 'statflags', 'activityType', 'code']
                
                for attr in attrs:
                    if hasattr(period, attr):
                        value = getattr(period, attr)
                        print(f"   {attr}: {value}")
                
                # Look for periods with special status
                print(f"\n🔍 Checking all periods for absence/status indicators...")
                interesting_periods = []
                
                for i, period in enumerate(my_tt):
                    flags = []
                    
                    # Check for various status indicators
                    if hasattr(period, 'statflags') and period.statflags:
                        flags.append(f"statflags:{period.statflags}")
                    if hasattr(period, 'code') and period.code:
                        flags.append(f"code:{period.code}")
                    if hasattr(period, 'lstext') and period.lstext:
                        flags.append(f"lstext:{period.lstext}")
                    if hasattr(period, 'activityType') and period.activityType:
                        flags.append(f"activity:{period.activityType}")
                    
                    if flags:
                        interesting_periods.append((i, flags))
                        
                print(f"   Found {len(interesting_periods)} periods with status indicators")
                for i, flags in interesting_periods:
                    print(f"     Period {i}: {', '.join(flags)}")
                        
        except Exception as e:
            print(f"❌ Timetable failed: {e}")
            import traceback
            traceback.print_exc()

        # Check what other data we can access
        print(f"\n🔍 Summary of accessible data:")
        methods_to_test = [
            ('klassen', lambda: s.klassen()),
            ('subjects', lambda: s.subjects()), 
            ('rooms', lambda: s.rooms()),
            ('holidays', lambda: s.holidays()),
            ('timegrid_units', lambda: s.timegrid_units()),
        ]
        
        for method_name, method_call in methods_to_test:
            try:
                data = method_call()
                print(f"   ✅ {method_name}: {len(data)} items")
            except Exception as e:
                print(f"   ❌ {method_name}: {e}")

except Exception as e:
    print(f"❌ Connection failed: {e}")
    import traceback
    traceback.print_exc()
