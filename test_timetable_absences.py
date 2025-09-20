import webuntis
from datetime import datetime, timedelta

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
        
        # Test my_timetable method
        print("\n📅 Testing my_timetable...")
        try:
            start = datetime.now() - timedelta(days=3)
            end = datetime.now() + timedelta(days=7)
            my_tt = s.my_timetable(start=start, end=end)
            print(f"✅ My timetable: {len(my_tt)} periods found")
            if my_tt:
                print(f"   Sample period keys: {my_tt[0].keys()}")
                print(f"   Sample period: {my_tt[0]}")
        except Exception as e:
            print(f"❌ My timetable: {e}")
        
        # Test the key method: timetable_with_absences!
        print("\n🏥 Testing timetable_with_absences...")
        try:
            start = datetime.now() - timedelta(days=30)  # Last month
            end = datetime.now() + timedelta(days=7)     # Next week
            
            # Get current student info first
            students = s.students()
            if students:
                student_id = students[0]['id']
                print(f"📋 Found student ID: {student_id}")
                
                # Try timetable_with_absences for this student
                tt_abs = s.timetable_with_absences(
                    start=start, 
                    end=end, 
                    student=student_id
                )
                print(f"✅ Timetable with absences: {len(tt_abs)} periods found")
                
                # Look for absence indicators
                absence_periods = [p for p in tt_abs if 'absence' in str(p).lower() or 'absent' in str(p).lower()]
                print(f"🔍 Periods mentioning absence: {len(absence_periods)}")
                
                if tt_abs:
                    print(f"\n📋 Sample period structure:")
                    for key, value in tt_abs[0].items():
                        print(f"   {key}: {value}")
                        
                # Look for any period with status codes that might indicate absence
                for period in tt_abs[:5]:  # Check first 5 periods
                    if any(key in ['status', 'code', 'absence', 'cancelled', 'substituted'] for key in period.keys()):
                        print(f"\n🔍 Period with status info: {period}")
                        
        except Exception as e:
            print(f"❌ Timetable with absences: {e}")
            import traceback
            traceback.print_exc()

        # Test exams with proper parameters
        print("\n📝 Testing exams with date range...")
        try:
            start = datetime.now() - timedelta(days=30)
            end = datetime.now() + timedelta(days=90)
            exams = s.exams(start=start, end=end)
            print(f"✅ Exams: {len(exams)} found")
            if exams:
                print(f"   Sample exam: {exams[0]}")
        except Exception as e:
            print(f"❌ Exams: {e}")
            
except Exception as e:
    print(f"❌ Connection failed: {e}")
    import traceback
    traceback.print_exc()
