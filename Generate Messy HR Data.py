"""
Messy HR Employee Performance Data Generator
Generates realistic, dirty CSV files for:
  - Data Warehouse ingestion (staging → cleaned star schema)
  - Power BI dashboard on Employee Performance Management

Business Problem:
  "Managers lack a unified view of employee performance across departments,
   making it difficult to identify top performers, underperformers, and whether
   performance is improving or declining over time."

Files Generated:
  1. employees_raw.csv              — 20,000 employees (dirty)
  2. departments_raw.csv            — Department reference data (dirty)
  3. performance_reviews_raw.csv    — Fact table: appraisal scores (dirty)
  4. training_raw.csv               — Training records (dirty)
  5. goals_raw.csv                  — Employee goals and achievement (dirty)

Scale:
  - 20,000 employees
  - ~60,000 performance reviews  (avg 3 per employee)
  - ~50,000 training records     (avg 2.5 per employee)
  - ~55,000 goals                (avg 2.75 per employee)
"""

import pandas as pd
import numpy as np
import random
import os
from datetime import datetime, timedelta

# ─── Seed for reproducibility ────────────────────────────────────────────────
random.seed(42)
np.random.seed(42)

OUTPUT_DIR = "hr_raw_data"
os.makedirs(OUTPUT_DIR, exist_ok=True)

NUM_EMPLOYEES       = 20_000
NUM_REVIEWS         = 60_000
NUM_TRAINING        = 50_000
NUM_GOALS           = 55_000
DUPE_FRAC           = 0.05     # 5% duplicate rows injected per file
CHUNK_SIZE          = 10_000   # write in chunks to avoid memory issues

print("=" * 65)
print("  HR Messy Data Generator — 20,000 Employee Scale")
print("=" * 65)

# ─── Helper utilities ─────────────────────────────────────────────────────────

def rand_date(start: str, end: str) -> str:
    s = datetime.strptime(start, "%Y-%m-%d")
    e = datetime.strptime(end,   "%Y-%m-%d")
    return (s + timedelta(days=random.randint(0, (e - s).days))).strftime("%Y-%m-%d")

def rand_dates_vectorized(start: str, end: str, n: int):
    """Fast vectorized date generation."""
    s = datetime.strptime(start, "%Y-%m-%d")
    e = datetime.strptime(end,   "%Y-%m-%d")
    days = (e - s).days
    offsets = np.random.randint(0, days, size=n)
    return [( s + timedelta(days=int(o)) ).strftime("%Y-%m-%d") for o in offsets]

DATE_FORMATS = [
    "%Y-%m-%d",
    "%d/%m/%Y",
    "%m-%d-%Y",
    "%d %b %Y",
    "%B %d, %Y",
    "%Y/%m/%d",
]

def messy_date_vec(dates: list) -> list:
    """Apply random date format to a list of date strings."""
    result = []
    for d in dates:
        if not d or random.random() < 0.06:
            result.append("")
            continue
        try:
            parsed = datetime.strptime(d, "%Y-%m-%d")
            result.append(parsed.strftime(random.choice(DATE_FORMATS)))
        except Exception:
            result.append(d)
    return result

GENDER_VARIANTS = {
    "Male":   ["Male", "male", "MALE", "M", "m", "Man"],
    "Female": ["Female", "female", "FEMALE", "F", "f", "Woman"],
}

DEPT_TYPOS = {
    "Engineering":        ["Engineering", "Enginering", "Engineerng", "ENGINEERING", "Eng", "engineering"],
    "Human Resources":    ["Human Resources", "Human Resource", "HR", "H.R.", "human resources", "Humaan Resources"],
    "Sales":              ["Sales", "sales", "SALES", "Slaes", "Sale"],
    "Marketing":          ["Marketing", "Marketting", "marketing", "MARKETING", "Mktg"],
    "Finance":            ["Finance", "Fiance", "finance", "FINANCE", "Fin"],
    "Operations":         ["Operations", "Operatons", "operations", "Ops", "OPERATIONS"],
    "Customer Support":   ["Customer Support", "Customer service", "Cust Support", "CS", "customer support"],
    "IT":                 ["IT", "I.T.", "Information Technology", "it", "Info Tech"],
    "Legal":              ["Legal", "legal", "LEGAL", "Legel", "Law"],
    "Research & Dev":     ["Research & Dev", "R&D", "r&d", "Research and Development", "RnD"],
    "Administration":     ["Administration", "Admin", "admin", "ADMIN", "Administraton"],
    "Procurement":        ["Procurement", "Procurment", "procurement", "PROCUREMENT", "Proc"],
}

def messy_dept(name: str) -> str:
    return random.choice(DEPT_TYPOS.get(name, [name]))

def inject_nulls_vec(values: list, prob: float = 0.07) -> list:
    return ["" if random.random() < prob else v for v in values]

def maybe_duplicate(df: pd.DataFrame, frac: float = DUPE_FRAC) -> pd.DataFrame:
    dupes = df.sample(frac=frac, random_state=7)
    return pd.concat([df, dupes], ignore_index=True).sample(frac=1, random_state=99).reset_index(drop=True)

def write_chunked(df: pd.DataFrame, path: str):
    """Write large DataFrame to CSV in chunks."""
    for i, chunk_start in enumerate(range(0, len(df), CHUNK_SIZE)):
        chunk = df.iloc[chunk_start:chunk_start + CHUNK_SIZE]
        chunk.to_csv(path, mode='a' if i > 0 else 'w', header=(i == 0), index=False)


# ─── Reference Data ───────────────────────────────────────────────────────────

DEPARTMENTS = [
    {"dept_id": f"D{str(i).zfill(3)}", "dept_name": n, "location": l}
    for i, (n, l) in enumerate([
        ("Engineering",      "Colombo"),
        ("Human Resources",  "Colombo"),
        ("Sales",            "Kandy"),
        ("Marketing",        "Colombo"),
        ("Finance",          "Galle"),
        ("Operations",       "Kandy"),
        ("Customer Support", "Colombo"),
        ("IT",               "Colombo"),
        ("Legal",            "Colombo"),
        ("Research & Dev",   "Gampaha"),
        ("Administration",   "Colombo"),
        ("Procurement",      "Kandy"),
    ], start=1)
]

DEPT_NAMES   = [d["dept_name"] for d in DEPARTMENTS]
DEPT_ID_MAP  = {d["dept_name"]: d["dept_id"] for d in DEPARTMENTS}

ROLES = {
    "Engineering":      ["Software Engineer", "Senior Engineer", "Tech Lead", "QA Engineer", "DevOps Engineer", "Solution Architect", "Junior Developer"],
    "Human Resources":  ["HR Executive", "HR Manager", "Recruiter", "HR Analyst", "Talent Acquisition Specialist", "Compensation Analyst"],
    "Sales":            ["Sales Executive", "Sales Manager", "Account Manager", "Business Dev Executive", "Regional Sales Lead", "Sales Coordinator"],
    "Marketing":        ["Marketing Executive", "Content Writer", "Digital Marketer", "Brand Manager", "SEO Specialist", "Campaign Manager"],
    "Finance":          ["Finance Analyst", "Accountant", "Finance Manager", "Payroll Officer", "Internal Auditor", "Budget Analyst"],
    "Operations":       ["Operations Executive", "Operations Manager", "Logistics Coordinator", "Supply Chain Analyst", "Process Engineer"],
    "Customer Support": ["Support Agent", "Senior Support Agent", "Support Team Lead", "Customer Success Manager", "Technical Support Engineer"],
    "IT":               ["IT Support", "System Admin", "Network Engineer", "IT Manager", "Cybersecurity Analyst", "Cloud Engineer"],
    "Legal":            ["Legal Counsel", "Compliance Officer", "Contract Manager", "Legal Analyst", "Paralegal"],
    "Research & Dev":   ["Research Scientist", "R&D Engineer", "Lab Technician", "Product Developer", "Innovation Lead"],
    "Administration":   ["Admin Executive", "Office Manager", "Executive Assistant", "Records Officer", "Facilities Manager"],
    "Procurement":      ["Procurement Officer", "Vendor Manager", "Purchasing Executive", "Supply Manager", "Category Analyst"],
}

FIRST_NAMES = [
    "Ashan","Dilani","Roshan","Nimal","Kumari","Chathura","Priya","Suresh","Tharushi","Kasun",
    "Malini","Arjun","Sachini","Dinesh","Samantha","Harsha","Nadeesha","Chamara","Isuru","Lakshmi",
    "Fathima","Mohamed","Ruwani","Thilina","Buddhika","Gayan","Hasini","Rajith","Amali","Vishwa",
    "Sanduni","Nuwan","Hiruni","Chamath","Lasith","Anjali","Ravindu","Shalini","Dasun","Nethmi",
    "Chanaka","Iresha","Asanka","Oshadi","Kavindu","Thisari","Bhanuka","Rashmi","Dimuth","Yomal",
    "Piumali","Shehan","Menaka","Dhanuka","Kaveesha","Rangi","Kithsiri","Avanthi","Pasindu","Navodya",
    "James","Sarah","Michael","Emma","David","Olivia","Daniel","Sophia","Matthew","Isabella",
    "Ryan","Mia","John","Ava","Chris","Charlotte","Alex","Amelia","Kevin","Harper",
]

LAST_NAMES = [
    "Perera","Silva","Fernando","Jayawardena","Gunawardena","Wickramasinghe","Rajapaksa","Bandara",
    "Dissanayake","Senanayake","Mendis","Karunaratne","Amarasinghe","Liyanage","Wijesinghe",
    "Hettiarachchi","Gamage","Ranasinghe","Pathirana","Samaraweera","Jayasuriya","Weerasinghe",
    "Gunasekara","Abeywickrama","Seneviratne","Kodituwakku","Ilangasinghe","Wimalasuriya",
    "Goonatilleke","Dassanayake","Smith","Johnson","Williams","Brown","Jones","Garcia","Miller",
    "Davis","Wilson","Taylor","Anderson","Thomas","Jackson","White","Harris","Martin",
]

REVIEW_PERIODS = [
    "Q1 2021","Q2 2021","Q3 2021","Q4 2021",
    "Q1 2022","Q2 2022","Q3 2022","Q4 2022",
    "Q1 2023","Q2 2023","Q3 2023","Q4 2023",
    "Q1 2024","Q2 2024","Q3 2024",
]

RATING_LABELS = {
    1: ["Poor","poor","POOR","1 - Poor","1-Poor"],
    2: ["Below Average","below average","BELOW AVG","2-Below Average","Below Avg"],
    3: ["Average","average","AVG","3 - Average","3-Avg"],
    4: ["Good","good","GOOD","4-Good","4 - Good"],
    5: ["Excellent","excellent","EXCELLENT","5 - Excellent","5-Excellent"],
}

COURSES = [
    "Leadership Fundamentals","Advanced Excel","Power BI Basics","Communication Skills",
    "Project Management","Python for Analytics","Customer Handling","Time Management",
    "Data Analysis","HR Compliance","Agile & Scrum","SQL Essentials","Presentation Skills",
    "Conflict Resolution","Financial Acumen","Design Thinking","Cybersecurity Awareness",
    "Cloud Computing Basics","Emotional Intelligence","Six Sigma Green Belt",
    "Strategic Planning","Negotiation Skills","Digital Transformation","Risk Management",
]

GOAL_TYPES = [
    "Sales Target","Project Delivery","Skill Development","Customer Satisfaction",
    "Cost Reduction","Productivity","Team Building","Process Improvement",
    "Revenue Growth","Quality Improvement","Innovation","Compliance","Training Completion",
]

COMMENTS = [
    "Good performer","Needs improvement","Exceeded expectations","Consistent results",
    "NEEDS IMPROVEMENT","","N/A","Great team player","Meets expectations",
    "Outstanding leadership","Room for growth","Reliable and dedicated",
    "Struggles with deadlines","Excellent communicator","Shows initiative",None,
    "needs improvement","EXCEEDED EXPECTATIONS","good performer","consistent results",
]

EMPLOYMENT_TYPES = ["Full-Time","full-time","Part-Time","Contract","CONTRACT","Permanent","permanent",""]
STATUSES_EMP     = ["Active","active","Inactive","Terminated","terminated","ACTIVE","On Leave","on leave"]
COMPLETION_STAT  = ["Completed","completed","COMPLETED","Incomplete","In Progress","in progress","Dropped",""]
GOAL_STATUSES    = ["Completed","completed","In Progress","in progress","Overdue","overdue","Cancelled","cancelled","","N/A"]
TRAINER_TYPES    = ["Internal","External","internal","EXTERNAL","Online","online",""]
CATEGORIES       = ["Technical","technical","Soft Skills","soft skills","TECHNICAL","Compliance","Leadership","","N/A"]
LOCATIONS        = ["Colombo","Kandy","Galle","Gampaha","Negombo","Kurunegala","Matara","Jaffna"]


# ─── 1. DEPARTMENTS ──────────────────────────────────────────────────────────
print("\n[1/5] Generating departments_raw.csv ...")

dept_rows = []
for d in DEPARTMENTS:
    row = {
        "dept_id":      d["dept_id"] if random.random() > 0.05 else "",
        "dept_name":    messy_dept(d["dept_name"]),
        "location":     d["location"] if random.random() > 0.08 else "",
        "manager_id":   f"EMP{random.randint(1000,9999)}" if random.random() > 0.15 else "",
        "created_date": messy_date_vec([rand_date("2010-01-01","2019-12-31")])[0],
        "status":       random.choice(["Active","active","ACTIVE","Inactive",""]),
        "headcount_budget": random.randint(50,500) if random.random() > 0.10 else "",
        "cost_center":  f"CC{random.randint(100,999)}" if random.random() > 0.12 else "",
    }
    dept_rows.append(row)
dept_rows.append(dept_rows[2].copy())   # inject 1 duplicate

dept_df = pd.DataFrame(dept_rows)
dept_df.to_csv(f"{OUTPUT_DIR}/departments_raw.csv", index=False)
print(f"   ✅  departments_raw.csv       → {len(dept_df)} rows")


# ─── 2. EMPLOYEES ────────────────────────────────────────────────────────────
print(f"\n[2/5] Generating employees_raw.csv ({NUM_EMPLOYEES:,} employees) ...")

# Generate base employee IDs (unique pool)
all_emp_ids = [f"EMP{str(i).zfill(6)}" for i in range(1, NUM_EMPLOYEES + 1)]

depts_assigned  = np.random.choice(DEPT_NAMES, size=NUM_EMPLOYEES)
genders_raw     = np.random.choice(["Male","Female"], size=NUM_EMPLOYEES)
dob_list        = rand_dates_vectorized("1970-01-01","2000-12-31", NUM_EMPLOYEES)
join_list       = rand_dates_vectorized("2010-01-01","2024-09-01", NUM_EMPLOYEES)
salaries        = np.round(np.random.uniform(35000, 350000, NUM_EMPLOYEES), 2)

emp_rows = []
for i in range(NUM_EMPLOYEES):
    dept_name = depts_assigned[i]
    dept_id   = DEPT_ID_MAP[dept_name]
    gender    = genders_raw[i]
    emp_id    = all_emp_ids[i]
    role      = random.choice(ROLES[dept_name])

    # Inject ~4% orphan dept_id
    dept_id_used = dept_id if random.random() > 0.04 else f"D{random.randint(50,99):03d}"

    row = {
        "employee_id":      emp_id,
        "first_name":       "" if random.random() < 0.03 else random.choice(FIRST_NAMES),
        "last_name":        "" if random.random() < 0.03 else random.choice(LAST_NAMES),
        "gender":           random.choice(GENDER_VARIANTS[gender]),
        "date_of_birth":    "" if random.random() < 0.06 else random.choice(DATE_FORMATS) and
                            datetime.strptime(dob_list[i],"%Y-%m-%d").strftime(random.choice(DATE_FORMATS)),
        "email":            "" if random.random() < 0.08 else f"{emp_id.lower()}@company.lk",
        "phone":            "N/A" if random.random() < 0.10 else f"07{random.randint(10000000,99999999)}",
        "department_id":    dept_id_used,
        "department_name":  messy_dept(dept_name),
        "job_title":        role.upper() if random.random() < 0.05 else role,
        "employment_type":  random.choice(EMPLOYMENT_TYPES),
        "join_date":        datetime.strptime(join_list[i],"%Y-%m-%d").strftime(random.choice(DATE_FORMATS)),
        "salary":           "" if random.random() < 0.06 else salaries[i],
        "status":           random.choice(STATUSES_EMP),
        "location":         "" if random.random() < 0.08 else random.choice(LOCATIONS),
        "manager_id":       "" if random.random() < 0.12 else f"EMP{random.randint(1,NUM_EMPLOYEES):06d}",
        "years_experience": "" if random.random() < 0.07 else random.randint(0, 30),
    }
    emp_rows.append(row)

emp_df = pd.DataFrame(emp_rows)
emp_df = maybe_duplicate(emp_df, frac=DUPE_FRAC)
write_chunked(emp_df, f"{OUTPUT_DIR}/employees_raw.csv")
print(f"   ✅  employees_raw.csv         → {len(emp_df):,} rows  (~{int(NUM_EMPLOYEES*DUPE_FRAC):,} duplicates injected)")
del emp_df  # free memory


# ─── 3. PERFORMANCE REVIEWS (FACT) ───────────────────────────────────────────
print(f"\n[3/5] Generating performance_reviews_raw.csv ({NUM_REVIEWS:,} reviews) ...")

review_dates = rand_dates_vectorized("2021-01-01","2024-09-30", NUM_REVIEWS)
perf_scores  = np.round(np.random.uniform(1.0, 5.0, NUM_REVIEWS), 1)
rating_nums  = np.random.choice([1,2,3,4,5], size=NUM_REVIEWS, p=[0.05,0.15,0.30,0.35,0.15])

review_rows = []
for i in range(NUM_REVIEWS):
    emp_id      = random.choice(all_emp_ids)
    r_date      = review_dates[i]
    score       = perf_scores[i]
    r_num       = int(rating_nums[i])
    period      = random.choice(REVIEW_PERIODS)
    dept        = random.choice(DEPT_NAMES)

    # Inject orphan FK (~4%)
    emp_id_used = emp_id if random.random() > 0.04 else f"EMP{random.randint(900000,999999)}"

    # Messy score: blank, trailing space, quoted string
    score_choice = random.random()
    if score_choice < 0.07:
        messy_score = ""
    elif score_choice < 0.14:
        messy_score = str(score) + " "
    elif score_choice < 0.18:
        messy_score = f'"{score}"'
    else:
        messy_score = str(score)

    row = {
        "review_id":           f"REV{random.randint(100000,999999)}",
        "employee_id":         emp_id_used,
        "review_period":       period if random.random() > 0.05 else period.replace(" ",""),
        "review_date":         datetime.strptime(r_date,"%Y-%m-%d").strftime(random.choice(DATE_FORMATS)),
        "reviewer_id":         "" if random.random() < 0.08 else f"EMP{random.randint(1,NUM_EMPLOYEES):06d}",
        "performance_score":   messy_score,
        "rating_label":        random.choice(RATING_LABELS[r_num]),
        "goals_achieved_pct":  "" if random.random() < 0.07 else f"{random.randint(20,100)}%",
        "communication_score": "" if random.random() < 0.06 else round(random.uniform(1,5),1),
        "teamwork_score":      "" if random.random() < 0.06 else round(random.uniform(1,5),1),
        "leadership_score":    "" if random.random() < 0.10 else round(random.uniform(1,5),1),
        "technical_score":     "" if random.random() < 0.06 else round(random.uniform(1,5),1),
        "comments":            random.choice(COMMENTS),
        "department":          messy_dept(dept),
        "created_at":          datetime.strptime(r_date,"%Y-%m-%d").strftime(random.choice(DATE_FORMATS)),
    }
    review_rows.append(row)

    # Write in chunks to avoid OOM
    if len(review_rows) >= CHUNK_SIZE:
        chunk_df = pd.DataFrame(review_rows)
        chunk_df = maybe_duplicate(chunk_df, frac=DUPE_FRAC)
        write_chunked(chunk_df, f"{OUTPUT_DIR}/performance_reviews_raw.csv")
        review_rows = []

if review_rows:
    chunk_df = pd.DataFrame(review_rows)
    chunk_df = maybe_duplicate(chunk_df, frac=DUPE_FRAC)
    write_chunked(chunk_df, f"{OUTPUT_DIR}/performance_reviews_raw.csv")

final_count = int(NUM_REVIEWS * (1 + DUPE_FRAC))
print(f"   ✅  performance_reviews_raw.csv → ~{final_count:,} rows  (~{int(NUM_REVIEWS*DUPE_FRAC):,} duplicates injected)")


# ─── 4. TRAINING RECORDS ─────────────────────────────────────────────────────
print(f"\n[4/5] Generating training_raw.csv ({NUM_TRAINING:,} records) ...")

training_rows = []
for i in range(NUM_TRAINING):
    emp_id     = random.choice(all_emp_ids)
    course     = random.choice(COURSES)
    start_date = rand_date("2020-01-01","2024-08-01")
    dur_days   = random.randint(1,15)
    end_date   = (datetime.strptime(start_date,"%Y-%m-%d") + timedelta(days=dur_days)).strftime("%Y-%m-%d")
    dept       = random.choice(DEPT_NAMES)

    emp_id_used = emp_id if random.random() > 0.04 else f"EMP{random.randint(900000,999999)}"

    row = {
        "training_id":       f"TRN{random.randint(100000,999999)}",
        "employee_id":       emp_id_used,
        "course_name":       course.lower() if random.random() < 0.08 else course,
        "category":          random.choice(CATEGORIES),
        "start_date":        datetime.strptime(start_date,"%Y-%m-%d").strftime(random.choice(DATE_FORMATS)),
        "end_date":          "" if random.random() < 0.07 else datetime.strptime(end_date,"%Y-%m-%d").strftime(random.choice(DATE_FORMATS)),
        "duration_days":     f"{dur_days} days" if random.random() < 0.08 else dur_days,
        "completion_status": random.choice(COMPLETION_STAT),
        "score":             "" if random.random() < 0.10 else random.randint(40,100),
        "cost_lkr":          "" if random.random() < 0.08 else round(random.uniform(5000,150000),2),
        "trainer":           random.choice(TRAINER_TYPES),
        "department":        messy_dept(dept),
        "year":              "" if random.random() < 0.05 else start_date[:4],
    }
    training_rows.append(row)

    if len(training_rows) >= CHUNK_SIZE:
        chunk_df = pd.DataFrame(training_rows)
        chunk_df = maybe_duplicate(chunk_df, frac=DUPE_FRAC)
        write_chunked(chunk_df, f"{OUTPUT_DIR}/training_raw.csv")
        training_rows = []

if training_rows:
    chunk_df = pd.DataFrame(training_rows)
    chunk_df = maybe_duplicate(chunk_df, frac=DUPE_FRAC)
    write_chunked(chunk_df, f"{OUTPUT_DIR}/training_raw.csv")

final_count = int(NUM_TRAINING * (1 + DUPE_FRAC))
print(f"   ✅  training_raw.csv           → ~{final_count:,} rows  (~{int(NUM_TRAINING*DUPE_FRAC):,} duplicates injected)")


# ─── 5. GOALS ────────────────────────────────────────────────────────────────
print(f"\n[5/5] Generating goals_raw.csv ({NUM_GOALS:,} records) ...")

MESSY_QUARTERS = [
    "Q1 2021","Q2 2021","Q3 2021","Q4 2021",
    "Q1 2022","Q2 2022","Q3 2022","Q4 2022",
    "Q1 2023","Q2 2023","Q3 2023","Q4 2023",
    "Q1 2024","Q2 2024","Q3 2024",
    "Q12022","Q2-2023","q3 2022","q2 2024",   # messy variants
    "2022 Q1","2023-Q3","",
]

goals_rows = []
for i in range(NUM_GOALS):
    emp_id    = random.choice(all_emp_ids)
    goal_type = random.choice(GOAL_TYPES)
    set_date  = rand_date("2021-01-01","2024-03-01")
    dur       = random.randint(30,180)
    due_date  = (datetime.strptime(set_date,"%Y-%m-%d") + timedelta(days=dur)).strftime("%Y-%m-%d")
    target    = round(random.uniform(50000,1000000),2)
    achieved  = round(target * random.uniform(0.2,1.4),2)
    dept      = random.choice(DEPT_NAMES)

    emp_id_used = emp_id if random.random() > 0.04 else f"EMP{random.randint(900000,999999)}"

    row = {
        "goal_id":          f"GOAL{random.randint(100000,999999)}",
        "employee_id":      emp_id_used,
        "goal_type":        goal_type.upper() if random.random() < 0.06 else goal_type,
        "goal_description": "" if random.random() < 0.08 else f"Achieve {goal_type.lower()} target for the period",
        "set_date":         datetime.strptime(set_date,"%Y-%m-%d").strftime(random.choice(DATE_FORMATS)),
        "due_date":         "" if random.random() < 0.07 else datetime.strptime(due_date,"%Y-%m-%d").strftime(random.choice(DATE_FORMATS)),
        "target_value":     "" if random.random() < 0.06 else target,
        "achieved_value":   "" if random.random() < 0.08 else achieved,
        "achievement_pct":  "" if random.random() < 0.06 else f"{round((achieved/target)*100,1)}%",
        "status":           random.choice(GOAL_STATUSES),
        "quarter":          random.choice(MESSY_QUARTERS),
        "department":       messy_dept(dept),
        "priority":         random.choice(["High","Medium","Low","high","LOW","MEDIUM","","N/A"]),
    }
    goals_rows.append(row)

    if len(goals_rows) >= CHUNK_SIZE:
        chunk_df = pd.DataFrame(goals_rows)
        chunk_df = maybe_duplicate(chunk_df, frac=DUPE_FRAC)
        write_chunked(chunk_df, f"{OUTPUT_DIR}/goals_raw.csv")
        goals_rows = []

if goals_rows:
    chunk_df = pd.DataFrame(goals_rows)
    chunk_df = maybe_duplicate(chunk_df, frac=DUPE_FRAC)
    write_chunked(chunk_df, f"{OUTPUT_DIR}/goals_raw.csv")

final_count = int(NUM_GOALS * (1 + DUPE_FRAC))
print(f"   ✅  goals_raw.csv              → ~{final_count:,} rows  (~{int(NUM_GOALS*DUPE_FRAC):,} duplicates injected)")


# ─── Summary ─────────────────────────────────────────────────────────────────
print("""
╔══════════════════════════════════════════════════════════════════╗
║           RAW DATA GENERATION COMPLETE — 20,000 EMPLOYEES       ║
╠══════════════════════════════════════════════════════════════════╣
║  Folder : hr_raw_data/                                           ║
║                                                                  ║
║  File                            Approx Rows                     ║
║  ─────────────────────────────── ───────────                     ║
║  departments_raw.csv                     13                      ║
║  employees_raw.csv                   21,000                      ║
║  performance_reviews_raw.csv         63,000                      ║
║  training_raw.csv                    52,500                      ║
║  goals_raw.csv                       57,750                      ║
║  ─────────────────────────────── ───────────                     ║
║  TOTAL                              ~194,263                     ║
╠══════════════════════════════════════════════════════════════════╣
║  Dirty Issues Injected:                                          ║
║    ✗ ~5% duplicate rows per file                                 ║
║    ✗ Inconsistent casing  (Male/MALE/male/M)                     ║
║    ✗ Mixed date formats   (6 different formats)                  ║
║    ✗ Dept name typos      (Enginering, Fiance, H.R.)             ║
║    ✗ Null / blank values  (3–12% per column)                     ║
║    ✗ Orphaned foreign keys (~4% invalid employee IDs)            ║
║    ✗ Wrong data types     (numbers as text, % as string)         ║
║    ✗ Inconsistent categories and quarter formats                 ║
╠══════════════════════════════════════════════════════════════════╣
║  Recommended Next Steps:                                         ║
║    1. Load CSVs into SQL staging schema                          ║
║    2. Clean & transform via SQL (DW layer)                       ║
║    3. Build star schema: dim_employee, dim_department,           ║
║       dim_date, fact_performance, fact_training, fact_goals      ║
║    4. Connect Power BI to warehouse                              ║
╚══════════════════════════════════════════════════════════════════╝
""")
