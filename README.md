# DETECT Dyad Quantitative Dashboard

Monitors consent and survey responses for the quantitative arm of the DETECT-RPC R33 phase. Care recipients enrolled in a partner home-based primary care program, and the family caregivers who help care for them, are invited to complete an online survey about their health, social support, and safety.

- **Patients** answer the survey about themselves.
- **Caregivers** answer about themselves, or about the person they care for (a *proxy* survey).

The goal is approximately **125 caregiving dyads** across seven sites: Baylor, Johns Hopkins, UCSF, UAB, UTSW, LBJ, and UTP.

## What the dashboard shows

An **All** page plus one page per site:

- **Banners:** 🔴 incomplete consents from people who said Yes to participating or follow-up; 🟡 other incomplete records (missing information, or answered No).
- **Value boxes:** consent forms started, consented, declined, incomplete, consent rate, patients, caregivers, proxy surveys, follow-up interest, complete dyads, surveys completed, and progress to the 125-dyad goal (All page).
- **Charts and tables:** consents over time, consent decisions by site, survey completion by instrument, caregiver-reported diagnoses, proxy relationship, follow-up contact times, and demographics (patient vs. caregiver).

Only counts are shown. No names, contact details, or record IDs appear on the site.

## Setup (one time)

```r
renv::restore()
keyring::key_set("detect_quant_redcap_api")   # paste your API token in the box
```

## Update and publish

From the project root:

```shell
Rscript data_management/data_01_quant_consent.R   # pull fresh data
quarto render                                     # build; check _site/sections/quant_consent_dashboard.html
git add . && git commit -m "YYYY-MM-DD Dashboard Update" && git push
quarto publish gh-pages
```

Pulled data stays in `data/` and is never committed (see `.gitignore`).

**First publish only:** accept creating the `gh-pages` branch, set **Settings → Pages** to the `gh-pages` branch, root folder, then commit the `_publish.yml` file Quarto creates.

**Preview with fake data** (never publish this build; the sidebar shows "Preview mode"):

```shell
Rscript data_management/mock_data/make_mock_data.R
DETECT_QUANT_MOCK=1 quarto render
```
