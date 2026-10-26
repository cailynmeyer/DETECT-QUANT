# Clean the raw-coded REDCap pull into one dashboard-ready row per record.
#
# Used by data_management/data_01_quant_consent.R (real REDCap data) and by
# data_management/mock_data/make_mock_data.R (fake data for previewing), so
# both go through identical cleaning. Requires r/codebook.R to be sourced.

library(dplyr, warn.conflicts = FALSE)

# REDCap date/datetime text ("YYYY-MM-DD HH:MM") -> Date. Anything else, such
# as a survey timestamp of "[not completed]", becomes NA.
as_redcap_date <- function(x) {
    as.Date(substr(as.character(x), 1, 10), format = "%Y-%m-%d")
}

# Self-report value, or the proxy value when the caregiver answered for the
# care recipient.
self_or_proxy <- function(self, proxy, is_proxy) {
    ifelse(is_proxy %in% TRUE, proxy, self)
}

# Form status with a 4th level for forms that were never opened.
form_status <- function(x) {
    out <- as.character(label_codes(x, form_status_labels))
    out[is.na(out)] <- "Not started"
    factor(out, levels = c("Complete", "Unverified", "Incomplete", "Not started"))
}

clean_quant_consent <- function(raw) {
    # consent_timestamp comes from export_survey_fields; mock data may lack it.
    if (!"consent_timestamp" %in% names(raw)) raw$consent_timestamp <- NA_character_

    cleaned <- raw |>
        mutate(
            # The consent survey was submitted: it has a completion timestamp,
            # or staff marked the form Complete (data entry, no survey timestamp).
            # A survey that was opened but never submitted has a timestamp of
            # "[not completed]" and fails both.
            consent_submitted = !is.na(as_redcap_date(consent_timestamp)) | consent_complete %in% 2,

            # Site: admin_institution defaults to 0, so fall back to the second
            # institution question when the first was left at its default.
            site_code = if_else(
                as.character(admin_institution) %in% names(institution_labels),
                as.character(admin_institution),
                as.character(admin_institution_2)
            ),
            site = label_codes(site_code, institution_labels),
            site_short = label_codes(site_code, institution_short),

            # Consent decision. Declining ends the survey (stop action), so a
            # "No" counts as declined whether or not the form was submitted.
            # "Yes" only counts once the consent survey was submitted; anything
            # else is an incomplete consent form.
            consent_f = case_when(
                co_authorization %in% 0 ~ "Declined",
                co_authorization %in% 1 & consent_submitted ~ "Consented",
                TRUE ~ "Incomplete"
            ),
            consent_f = factor(consent_f, levels = c("Consented", "Declined", "Incomplete")),
            consented = consent_f == "Consented",
            # Ticked "Yes" to participating, even if the form wasn't submitted
            consent_yes = co_authorization %in% 1,

            # Date consent was signed; survey start date when it was not signed
            consent_date = coalesce(as_redcap_date(co_sign_dt), as_redcap_date(admin_start_dt)),
            start_date = as_redcap_date(admin_start_dt),

            role_f = label_codes(admin_role, role_labels),
            is_proxy = admin_role %in% 2 & co_sign_rep %in% 1,

            # Who the survey answers describe
            respondent_f = case_when(
                admin_role %in% 1 ~ "Patient (self-report)",
                is_proxy ~ "Patient (caregiver proxy)",
                admin_role %in% 2 ~ "Caregiver (self-report)",
                TRUE ~ NA_character_
            ),
            respondent_f = factor(
                respondent_f,
                levels = c("Patient (self-report)", "Patient (caregiver proxy)", "Caregiver (self-report)")
            ),

            followup_f = label_codes(admin_qual, yesno_labels),
            relationship_f = label_codes(co_rep_relationship, relationship_labels),

            # Demographics of the person the answers describe
            hispanic_f = label_codes(self_or_proxy(sode_hispanic, sode_hispanic_proxy, is_proxy), hispanic_labels),
            sex_f = label_codes(self_or_proxy(sogi_sex, sogi_sex_proxy, is_proxy), sex_labels),
            marital_f = label_codes(self_or_proxy(sode_marital, sode_marital_proxy, is_proxy), marital_labels),
            military_f = label_codes(self_or_proxy(sode_military, sode_military_proxy, is_proxy), military_labels),
            school_f = label_codes(self_or_proxy(sode_school, sode_school_proxy, is_proxy), school_labels),
            income_f = label_codes(self_or_proxy(sode_income, sode_income_proxy, is_proxy), income_labels),
            age = suppressWarnings(as.numeric(self_or_proxy(sode_age, sode_age_proxy, is_proxy))),
            household_size = suppressWarnings(as.numeric(self_or_proxy(sode_people, sode_people_proxy, is_proxy)))
        )

    # Race is a checkbox: race___<code> is TRUE when that box was ticked.
    for (code in names(race_labels)) {
        self_col <- paste0("sode_race___", code)
        proxy_col <- paste0("sode_race_proxy___", code)
        self_val <- if (self_col %in% names(cleaned)) cleaned[[self_col]] else NA
        proxy_val <- if (proxy_col %in% names(cleaned)) cleaned[[proxy_col]] else NA
        cleaned[[paste0("race___", code)]] <- self_or_proxy(self_val, proxy_val, cleaned$is_proxy) %in% 1
    }

    # Form status for every instrument
    for (form in names(instrument_labels)) {
        col <- paste0(form, "_complete")
        status <- if (col %in% names(cleaned)) cleaned[[col]] else NA
        cleaned[[paste0(form, "_status")]] <- form_status(status)
    }

    cleaned |>
        select(
            admin_record_id, admin_dyad,
            site_code, site, site_short,
            consent_f, consented, consent_yes, consent_submitted, consent_date, start_date,
            role_f, is_proxy, respondent_f,
            followup_f, starts_with("admin_qual_time___"),
            relationship_f, starts_with("sode_adrd___"),
            hispanic_f, starts_with("race___"), sex_f, marital_f, military_f,
            school_f, income_f, age, household_size,
            ends_with("_status")
        )
}
