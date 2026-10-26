# Value labels for the DETECT Dyad Quantitative REDCap project (PID 9147).
#
# Transcribed from the data dictionary codebook
# ("DETECT Dyad Quantitative _ REDCap.pdf", exported 10/26/2026). Data is pulled
# with raw codes; these lookups turn the codes into the labels shown on the
# dashboard. If the REDCap instrument changes, update the matching vector here.

# --- Consent ------------------------------------------------------------------

institution_labels <- c(
    "1" = "Baylor College of Medicine - BT House Calls",
    "2" = "Johns Hopkins - JHOME",
    "3" = "UCSF - Care at Home Program",
    "4" = "University of Alabama - UAB House Calls",
    "5" = "UT Southwestern - COVE",
    "6" = "UTH Houston - LBJ House Calls",
    "7" = "UTH Houston - UT Physicians House Calls"
)

# Short names used for page titles and plot axes
institution_short <- c(
    "1" = "Baylor",
    "2" = "Johns Hopkins",
    "3" = "UCSF",
    "4" = "UAB",
    "5" = "UTSW",
    "6" = "LBJ",
    "7" = "UTP"
)

# co_authorization: "Would you like to participate in this study?"
yesno_labels <- c("1" = "Yes", "0" = "No")

# admin_role: "Which best describes you?"
role_labels <- c(
    "1" = "Patient",
    "2" = "Caregiver"
)

# co_sign_rep: "Who do you want to answer questions about right now?"
sign_rep_labels <- c(
    "0" = "About themself",
    "1" = "About the care recipient (proxy)"
)

# co_rep_relationship: caregiver's relationship to the care recipient
relationship_labels <- c(
    "1" = "Spouse",
    "2" = "Ex-Spouse",
    "3" = "Unmarried Partner",
    "4" = "Biological Child",
    "5" = "Son or Daughter in Law",
    "6" = "Biological Grandchild",
    "7" = "Step-Grandchild",
    "8" = "Brother or Sister",
    "9" = "Step-Brother or Step-Sister",
    "10" = "Niece or nephew",
    "11" = "Brother or sister",
    "12" = "Other Family Member",
    "13" = "Friend",
    "14" = "Neighbor"
)

# Checkbox: admin_qual_time___<code> (preferred follow-up contact time)
qual_time_labels <- c(
    "1" = "Before 9AM",
    "2" = "9AM-11AM",
    "3" = "11AM-1PM",
    "4" = "1PM-3PM",
    "5" = "3PM-5PM",
    "6" = "After 5PM",
    "7" = "Anytime"
)

# Checkbox: sode_adrd___<code> (caregiver-reported diagnosis of care recipient)
adrd_labels <- c(
    "1" = "Alzheimer's Disease",
    "2" = "Another type of dementia",
    "3" = "Mild Cognitive Impairment (MCI)",
    "4" = "None of these",
    "777" = "Don't Know / Not sure",
    "999" = "Prefer not to answer"
)

# --- Form status (every instrument's *_complete field) -------------------------

form_status_labels <- c(
    "0" = "Incomplete",
    "1" = "Unverified",
    "2" = "Complete"
)

# Instrument form names in survey order -> display names
instrument_labels <- c(
    consent = "Consent",
    sociodemographics = "Sociodemographics",
    social_isolationsupport = "Social Isolation/Support",
    general_health = "General Health",
    substance_use = "Substance Use",
    selfreport = "Self-Report",
    caregiver_questions = "Caregiver Questions",
    end = "End"
)

# --- Sociodemographics ----------------------------------------------------------
# Self and proxy versions of each item share the same choices.

missing_labels <- c("777" = "Don't Know / Not sure", "999" = "Prefer not to answer")

hispanic_labels <- c("1" = "Yes", "2" = "No", missing_labels)

race_labels <- c(
    "1" = "White",
    "2" = "Black or African American",
    "3" = "Asian",
    "4" = "American Indian or Alaska Native",
    "5" = "Native Hawaiian or other Pacific Islander",
    "6" = "Middle Eastern or North African",
    "7" = "Other Race",
    missing_labels
)

sex_labels <- c("1" = "Male", "2" = "Female", missing_labels)

marital_labels <- c(
    "1" = "Married",
    "2" = "Living as an unmarried or common-law couple",
    "3" = "Separated",
    "4" = "Divorced",
    "5" = "Widowed",
    "6" = "Single or never married",
    missing_labels
)

military_labels <- c("1" = "Yes", "2" = "No", missing_labels)

school_labels <- c(
    "1" = "Did not complete high school or GED",
    "2" = "High school graduate or GED",
    "3" = "Some college (no degree)",
    "4" = "Associate's degree",
    "5" = "Bachelor's degree (BA, AB, BS, etc.)",
    "6" = "Some graduate or professional school (no degree)",
    "7" = "Graduate or professional school degree (MS, MA, MD, PhD, etc.)",
    missing_labels
)

income_labels <- c(
    "1" = "$10,000 or less",
    "2" = "Between $10,001 and $20,000",
    "3" = "Between $20,001 and $35,000",
    "4" = "Between $35,001 and $50,000",
    "5" = "Between $50,001 and $75,000",
    "6" = "Between $75,001 and $100,000",
    "7" = "More than $100,000",
    missing_labels
)

# Turn a raw-coded vector into a factor using one of the lookups above. Level
# order follows the lookup, so plots keep the codebook's answer order.
label_codes <- function(x, labels) {
    factor(unname(labels[as.character(x)]), levels = unique(unname(labels)))
}
