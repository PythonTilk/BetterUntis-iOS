import webuntis
from datetime import datetime, timedelta
import json

server = 'mese.webuntis.com'
school = 'IT-Schule+Stuttgart'
username = 'noel.burkhardt'
password = 'Noel2008'

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
