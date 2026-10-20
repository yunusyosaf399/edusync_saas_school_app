"""D1 operation acceptance on the disposable local stack only."""
from __future__ import annotations
import re
import subprocess
import tempfile
from pathlib import Path
from foundation_local_ci import parse_tap

ROOT = Path(__file__).resolve().parents[2]
DOMAIN_TESTS = [["01_employee_create.sql",37],["02_academic_class.sql",25],["03_employee_state.sql",22],["04_employee_state_approval.sql",42],["05_subject_teacher_assignment.sql",25],["06_subject_teacher_retroactive_p2.sql",32],["07_subject_teacher_p2_reject_requester_stale.sql",37],["08_family_child_access_boundaries.sql",34],["09_family_principal_membership_authorization.sql",38],["10_family_relationship_direct_access.sql",52],["11_family_relationship_p1_approval.sql",66],["12_family_principal_membership_p1_approval.sql",40],["13_family_membership_p1_end_correct.sql",85],["14_family_membership_p1_stale_conflicts.sql",35],["15_family_membership_p1_protected_request_read.sql",49],["16_family_membership_p1_policy_multistep.sql",63],["17_family_relationship_primary_multibasis.sql",41],["18_family_relationship_p1_checked_request_read.sql",36],["19_family_relationship_p1_cross_campus_scope.sql",34],["20_family_relationship_p1_primary_replacement.sql",44],["21_family_relationship_p1_reviewer_scope_stale_apply.sql",36],["22_family_relationship_p1_retired_policy_stale_apply.sql",43],["23_family_relationship_p1_policy_replacement_stale_apply.sql",65],["24_family_relationship_p1_approved_policy_ambiguity.sql",77],["25_family_relationship_p1_approval_to_direct_route_stale_apply.sql",84],["26_family_relationship_p1_direct_to_approval_route.sql",80],["27_family_portal_checked_current_read_revocation.sql",69],["28_family_portal_student_roster_profile_disclosure.sql",67],["29_family_portal_emergency_contact_current_checked_read.sql",77],["30_family_portal_historical_relationship_alternate_basis.sql",78],["31_family_portal_two_family_child_access_isolation.sql",81],["32_academic_subject_lifecycle_authorization.sql",54],["33_academic_class_offering_lifecycle_authorization.sql",52],["34_academic_section_offering_lifecycle_authorization.sql",56],["35_academic_section_room_assignment_history_authorization.sql",77],["36_academic_capacity_change_revision_authorization.sql",85],["37_student_roll_policy_current_checked_read_authorization.sql",35],["38_student_roll_policy_retained_history_defensive_invariants.sql",40],["39_employee_department_catalog_lifecycle_authorization.sql",57],["40_employee_designation_catalog_lifecycle_authorization.sql",59],["41_employee_job_assignment_p1_direct_lifecycle_authorization.sql",67],["42_employee_campus_affiliation_p1_direct_lifecycle_authorization.sql",74],["43_employee_profile_p1_direct_photo_authorization.sql",49],["44_employee_qualification_p1_direct_history_authorization.sql",46],["45_employee_experience_p1_direct_history_authorization.sql",51],["46_teacher_capability_p1_direct_history_authorization.sql",50],["47_employee_identity_p2_approval_history_authorization.sql",40],["48_class_teacher_p0_direct_history_authorization.sql",32],["49_employee_identity_p2_reject_requester_stale.sql",32],["50_teacher_capability_p1_approval_reject.sql",31],["51_class_teacher_p2_retroactive_correct_approval.sql",23],["52_class_teacher_p2_reject_replay.sql",20],["53_employee_identity_p2_retired_policy_invalidation.sql",29],["54_teacher_capability_p1_retired_policy_invalidation.sql",28],["55_class_teacher_p0_capability_employment_gate.sql",15],["56_student_status_p1_direct_lifecycle.sql",11],["57_student_emergency_contact_p1_direct_history.sql",12],["58_student_identity_p2_approval_history.sql",11],["59_student_special_p2_approval_history.sql",11],["60_student_status_correct_p2_approval_history.sql",10],["61_student_enrollment_place_p0_initial_roll.sql",18],["62_student_enrollment_end_p1_direct_history.sql",28],["63_student_enrollment_move_p1_direct_section_history.sql",34],["64_family_primary_context_p0_select_correct_end.sql",37],["65_remaining_student_commands_fail_closed.sql",38],["66_student_profile_p1_direct_history_authorization.sql",33],["67_student_profile_p1_approval_review_apply.sql",41],["68_student_profile_p1_reject_no_effect.sql",20],["69_student_profile_p1_retired_policy_invalidation.sql",21],["70_student_profile_p1_requester_scope_revocation.sql",19],["71_student_profile_p1_target_version_drift.sql",17],["72_student_profile_p1_replacement_policy_stale_apply.sql",22],["73_student_profile_p1_ambiguous_active_policy.sql",22],["74_student_profile_p1_reviewer_scope_revoked.sql",23]]

DOMAIN_TESTS.extend([["75_db01_allocator_retained_history.sql",12],
                     ["76_db01_end_stored_policy_prelock.sql",30],
                     ["77_db01_retained_result_pair_private_acl.sql",30],
                     ["78_db01_direct_receipt_provenance_private_acl.sql",24],
                     ["79_db01_approval_application_receipt_guard.sql",14],
                     ["80_school_local_roll_business_date.sql",24]])

# DB-02 isolated non-activating reviewer acceptance. Preserve #1-80 and
# DB-01 owner-managed #81 when its separate PR is integrated.
DOMAIN_TESTS.append(["82_db02_school_reviewer_candidates.sql",10])
DOMAIN_TESTS.append(["83_db02_roll_policy_source_preflight.sql",18])

def render_fixture(source: str,fixture: str) -> str:
    marker = chr(92)+"ir fixtures/command_actor.sql"
    if source.count(marker) != 1:
        raise RuntimeError("D1_BUSINESS_FIXTURE_MARKER")
    return source.replace(marker,fixture)

def run_business_tests() -> int:
    total = 0
    for filename, expected in DOMAIN_TESTS:
        path = "supabase/tests/domain/" + filename
        source = (ROOT / path).read_text(encoding="utf-8")
        if not source.startswith("--") or "BEGIN;" not in source or not source.rstrip().endswith("ROLLBACK;"):
            raise RuntimeError("D1_BUSINESS_TRANSACTION_BOUNDARY " + filename)
        # CLI runs SQL in its test container; inline the shared fixture instead
        # of relying on psql include paths inside that container.
        fixture = (ROOT/"supabase/tests/domain/fixtures/command_actor.sql").read_text(encoding="utf-8")
        rendered = render_fixture(source,fixture)
        with tempfile.TemporaryDirectory(prefix="d1_acceptance_",dir=ROOT/"supabase/tests/database") as directory:
            generated = Path(directory)/filename
            generated.write_text(rendered,encoding="utf-8")
            result = subprocess.run(["supabase","test","db",str(generated.relative_to(ROOT)),"--local"],
                cwd=ROOT,text=True,capture_output=True,timeout=300)
        output = result.stdout + "\n" + result.stderr
        if result.returncode:
            # Local synthetic tests contain no credentials. Redact any connection URI/token.
            sanitized = re.sub(r"postgres(?:ql)?://[^\s]+","[local connection redacted]",output)
            sanitized = re.sub(r"[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}","[token redacted]",sanitized)
            lines = [line for line in sanitized.splitlines() if "Connecting to" not in line]
            raise RuntimeError("D1_BUSINESS_TEST_FAIL " + filename + "\n" + "\n".join(lines[-100:]))
        count = parse_tap(output,expected)
        total += count
        print("D1_BUSINESS_TEST_PASS " + filename + " " + str(count) + "/" + str(expected))
    print("D1_BUSINESS_PASS " + str(total) + " assertions; coverage is incremental")
    return total
