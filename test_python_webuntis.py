import webuntis
import traceback
from datetime import datetime, timedelta

# Your WebUntis credentials
server = 'mese.webuntis.com'
school = 'IT-Schule+Stuttgart'
username = 'noel.burkhardt'
password = 'Noel2008'

print("🔄 Testing Python WebUntis library...")
print(f"Server: {server}")
print(f"School: {school}")
print(f"Username: {username}")

try:
    # Create session and login
    with webuntis.Session(
        username=username,
        password=password,
        server=server,
        school=school,
        useragent='BetterUntis-Test'
    ).login() as s:
        
        print("✅ Successfully logged in!")
        
        # Try to get current user info
        print("\n📋 Testing available methods...")
        
        # Test basic methods
        try:
            klassen = s.klassen()
            print(f"✅ Classes: {len(klassen)} found")
        except Exception as e:
            print(f"❌ Classes: {e}")
        
        # Test subjects
        try:
            subjects = s.subjects()
            print(f"✅ Subjects: {len(subjects)} found")
        except Exception as e:
            print(f"❌ Subjects: {e}")
        
        # Test teachers
        try:
            teachers = s.teachers()
            print(f"✅ Teachers: {len(teachers)} found")
        except Exception as e:
            print(f"❌ Teachers: {e}")
        
        # Test rooms
        try:
            rooms = s.rooms()
            print(f"✅ Rooms: {len(rooms)} found")
        except Exception as e:
            print(f"❌ Rooms: {e}")
            
        # Test timetable
        try:
            today = datetime.now()
            start = today - timedelta(days=1)
            end = today + timedelta(days=7)
            timetable = s.timetable(start=start, end=end)
            print(f"✅ Timetable: {len(timetable)} periods found")
        except Exception as e:
            print(f"❌ Timetable: {e}")
        
        # Test absences (key method we're looking for!)
        print("\n🏥 Testing absence methods...")
        try:
            # Try different absence methods
            absence_methods = [
                ('own_absences', lambda: s.own_absences()),
                ('absences', lambda: s.absences()),
            ]
            
            for method_name, method_call in absence_methods:
                try:
                    absences = method_call()
                    print(f"✅ {method_name}: {len(absences)} absences found")
                    if absences:
                        print(f"   Sample absence: {absences[0]}")
                except AttributeError:
                    print(f"⚠️ {method_name}: Method not available")
                except Exception as e:
                    print(f"❌ {method_name}: {e}")
            
        except Exception as e:
            print(f"❌ Absence testing failed: {e}")
        
        # Test exams
        print("\n📝 Testing exam methods...")
        try:
            # Try different exam methods  
            exam_methods = [
                ('exams', lambda: s.exams()),
                ('own_exams', lambda: s.own_exams()),
            ]
            
            for method_name, method_call in exam_methods:
                try:
                    exams = method_call()
                    print(f"✅ {method_name}: {len(exams)} exams found")
                    if exams:
                        print(f"   Sample exam: {exams[0]}")
                except AttributeError:
                    print(f"⚠️ {method_name}: Method not available")
                except Exception as e:
                    print(f"❌ {method_name}: {e}")
                    
        except Exception as e:
            print(f"❌ Exam testing failed: {e}")
        
        # Explore available methods
        print("\n🔍 Available session methods:")
        session_methods = [method for method in dir(s) if not method.startswith('_')]
        for method in sorted(session_methods):
            print(f"   - {method}")

except Exception as e:
    print(f"❌ Login failed: {e}")
    print("Full traceback:")
    traceback.print_exc()
