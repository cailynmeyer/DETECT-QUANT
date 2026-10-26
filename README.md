# DETECT Dyad Quantitative Dashboard

Monitors consent and survey responses for the DETECT-RPC R33 **Dyad Quantitative** survey (REDCap PID 9147, HSC-SPH-24-0123). It is styled to match the [DETECT Tool dashboard](../DETECT/sections/detect_tool_dashboard.qmd): same navbar and logo, green value boxes, grey sidebar summary tables, teal/navy `ggplotly` charts, and shaded `DT` tables.

## Quick update

From the project root, with the `detect_quant_redcap_api` token set up (see [Setup](#setup)):

```shell
Rscript data_management/data_01_quant_consent.R   # 1. pull fresh data from REDCap
quarto render                                     # 2. rebuild the site
open _site/sections/quant_consent_dashboard.html  # 3. check it
```

Then commit the code changes and publish (`quarto publish gh-pages`), the same way as the DETECT dashboards. Pulled data stays in `data/`, which is gitignored along with every common data-file type (`.RDS`, `.csv`, `.xlsx`, `.duckdb`, …).

## What the dashboard shows

One **All** page plus one page per site (Baylor, Johns Hopkins, UCSF, UAB, UTSW, LBJ, UTP). Every page uses the same layout (`sections/_consent_page.qmd`):

| Section | Contents |
|---|---|
| Value boxes | Consent forms started, consented, declined, incomplete, consent rate; patients / caregivers consented, caregiver proxy surveys, follow-up interview interest; dyads with both members consented; surveys completed |
| Consents over time | Cumulative consents per week, patient vs. caregiver |
| Consent decisions by site *(All page only)* | Consented / declined / incomplete by site, plus a site table. The *Progress to Goal* box is also All-only |
| Survey completion | Form status (Complete / Unverified / Incomplete / Not started) for each instrument among consented participants |
| Consent details | Caregiver-reported diagnoses of the care recipient (`sode_adrd`), proxy relationship, preferred follow-up contact times |
| Demographics | Sex, Hispanic origin, race, age band, marital status, schooling, income, military service, for patients (self-report or caregiver proxy) vs. caregivers |

### Definitions

- **Consented**: `co_authorization = 1` **and** the consent survey was submitted. Submitted means `consent_timestamp` holds a date, or the Consent form status is Complete (for staff data entry, which leaves no survey timestamp).
- **Declined**: `co_authorization = 0`. Declining stops the survey, so it counts whether or not the form was submitted.
- **Incomplete**: everything else, i.e. consent surveys that were opened but never submitted (timestamp `[not completed]`), including ones where "Yes" was ticked but never submitted.
- **Consent rate**: consented ÷ (consented + declined). Incomplete forms are left out.
- **Record banners** (top of the All page and the matching site page). Both show counts only, with no record IDs or names. Each record appears in at most one, and a banner disappears once its records are fixed:
  - 🔴 **Red, "Incomplete, but interested in consent or follow-up":** the consent survey was never submitted, but the person said Yes to participating (`co_authorization = 1`) or to a follow-up interview (`admin_qual = 1`). Shows a count only, with no record IDs. Once a red record is submitted, any other problem on it, such as a missing site, moves to the yellow banner.
  - 🟡 **Yellow, "N records incomplete: missing / responded no to consent and/or follow-up":** every other record with a problem: consent survey not submitted with no Yes answers, no site recorded (these show only on the All page), or consented but no patient/caregiver role recorded.
- **Site**: `admin_institution`, which is hidden on the survey, defaults to 0 ("Default"), and is normally set by the survey link. If it's still 0, `admin_institution_2` is used. Records with neither go under **Site not recorded**: they count on the All page and in the by-site chart and table, but not on any site page, and a banner on the All page flags them. (`admin_institution_2` currently never shows, because its branching logic is `[admin_institution] = ''` and the default makes the field 0, not blank.)
- **Proxy survey**: `admin_role = 2` (caregiver) and `co_sign_rep = 1` (answering about the care recipient). Proxy answers (`*_proxy` fields) count toward the **Patient** demographics.
- **Dyad**: an `admin_dyad` ID with at least one consented patient and one consented caregiver.
- **Enrollment goal**: **125 dyads**, matching the consent form ("approximately 125 caregiving dyads"). The *Progress to Goal* box is dyads with both a patient and a caregiver consented, divided by 125. Change `enrollment_goal_dyads` in `sections/quant_consent_dashboard.qmd` if the target changes; the box title updates with it.
- **Caregiver Questions** completion is counted for caregivers only.
- **Counts are surveys, not unique people.** Repeating instruments are off in REDCap, so each survey is its own record. A caregiver who answers once about themselves and again about the care recipient counts as two consent forms.

### Privacy

The dashboard shows **counts only**. No direct identifiers appear anywhere on the site, including the data embedded in charts and tables:

- **Never pulled from REDCap:** names (participant and care recipient), email, signature, phone number, date of birth, free-text answers. The project has no MRN field. See `fields_to_pull` in `data_management/data_01_quant_consent.R`.
- **Pulled but never displayed:** record ID and Dyad Interview ID. Dyad Interview ID is only used to count dyads.
- **Shown:** dates (consent week on hover, data time period in the sidebar), and age in bands only.

If you add a field to `fields_to_pull`, check that it isn't a direct identifier first.

## Setup

Shared setup (R, Quarto, renv, keyring) is the same as the [DETECT README](../DETECT/README.md#installation).

1. **Dependencies.** This project has no `renv.lock` yet. In R, from the project root:
   ```r
   renv::init()   # then renv::snapshot() after installing anything missing
   ```
   Packages used: `here`, `dplyr`, `tidyr`, `ggplot2`, `plotly`, `DT`, `flextable`, `officer`, `REDCapR`, `keyring`, `lubridate`, `knitr`, `fs`, `glue`.
2. **API token.** Request a REDCap API token for **DETECT Dyad Quantitative (PID 9147)** with *export* rights, then store it:
   ```r
   keyring::key_set("detect_quant_redcap_api")
   ```
   or add `detect_quant_redcap_api=<token>` to a `.Renviron` file in the project root (gitignored).

## Refreshing data and building

```shell
# from the project root
Rscript data_management/data_01_quant_consent.R   # REDCap -> data/quant/quant_consent_cleaned.RDS
quarto render                                     # preview: _site/index.html
```

`data_01_quant_consent.R` requests **only** the fields the dashboard uses (see `fields_to_pull`). Names, email, signature, phone number, and date of birth are never pulled, and age is shown only in bands. Cleaning lives in `r/clean_quant_consent.R`. Value labels come from `r/codebook.R`, which was transcribed from the codebook PDF; update it if the REDCap instruments change.

### Previewing without REDCap access

```shell
Rscript data_management/mock_data/make_mock_data.R   # FAKE records, same shape as the REDCap pull
DETECT_QUANT_MOCK=1 quarto render
```

The sidebar shows **"Preview mode: Showing FAKE mock data"** whenever the mock file is in use. Never publish a mock build.

## Repository structure

| Path | What it holds |
|---|---|
| `index.qmd` | Overview page |
| `sections/quant_consent_dashboard.qmd` | Dashboard: loads data, sidebar, and knits one page per site from the template |
| `sections/_consent_page.qmd` | Shared page layout (the leading `_` stops Quarto rendering it on its own) |
| `data_management/data_01_quant_consent.R` | REDCap pull + save |
| `data_management/mock_data/make_mock_data.R` | Fake data generator for previews |
| `r/codebook.R` | Value labels from the REDCap codebook |
| `r/clean_quant_consent.R` | Cleaning shared by the real pull and the mock data |
| `r/quant_dashboard_helpers.R` | Value-box counts, plots, tables, sidebar boxes |
| `r/get_api_token.R`, `r/add_shade_column_x_rows.R` | Copied from the DETECT repo |
| `assets/`, `graphics/` | DETECT CSS and logos |
| `data/` | Pulled data. **Not tracked in git** |

## Publishing

The site publishes to GitHub Pages from the `gh-pages` branch, the same as the DETECT dashboards. `quarto publish` renders the site and pushes only the built HTML to `gh-pages`. Pulled data is never committed.

```shell
Rscript data_management/data_01_quant_consent.R   # fresh data
git add . && git commit -m "YYYY-MM-DD Dashboard Update" && git push
quarto publish gh-pages
```

Make sure `DETECT_QUANT_MOCK` is **not** set when publishing (`echo $DETECT_QUANT_MOCK` should print nothing). The sidebar says "Preview mode" if mock data slipped in.

**First publish only:** Quarto offers to create the `gh-pages` branch. Accept, then in the GitHub repo go to **Settings → Pages** and set the source to the `gh-pages` branch, root folder. Commit the `_publish.yml` file Quarto creates. The site goes live at `https://<github-user>.github.io/<repo-name>/` a minute or two later.

| Page | Path |
| --- | --- |
| Overview | `/` |
| Dyad Quantitative Consent Dashboard | `/sections/quant_consent_dashboard.html` |

The published site is public. It shows counts and dates only, with no direct identifiers (see [Privacy](#privacy)).
