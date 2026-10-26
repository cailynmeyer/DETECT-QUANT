# Summary, plot, and table helpers for the Dyad Quantitative Consent dashboard.
#
# Styling follows the DETECT Tool dashboard: theme_classic ggplots wrapped in
# ggplotly with fixed axes, the same teal/navy palette, white-on-grey sidebar
# flextables, and DT tables with grouped row shading. Requires r/codebook.R and
# r/add_shade_column_x_rows.R to be sourced.

library(dplyr, warn.conflicts = FALSE)
library(tidyr)
library(ggplot2)
library(plotly)
library(DT)
library(flextable)
library(officer)

# --- Palette (from the DETECT Tool dashboard) ----------------------------------

role_colors <- c("Patient" = "#219ebc", "Caregiver" = "#023047")

respondent_colors <- c(
    "Patient (self-report)" = "#219ebc",
    "Patient (caregiver proxy)" = "#AFD5E0",
    "Caregiver (self-report)" = "#023047"
)

consent_colors <- c(
    "Consented" = "#219ebc",
    "Declined" = "#023047",
    "Incomplete" = "#AFD5E0"
)

status_colors <- c(
    "Complete" = "#219ebc",
    "Unverified" = "#AFD5E0",
    "Incomplete" = "#023047",
    "Not started" = "#D9D9D9"
)

single_color <- "#219ebc"

# --- Small utilities -------------------------------------------------------------

pct <- function(num, den) {
    if (den == 0) "—" else paste0(round(100 * num / den), "%")
}

# Patient-subject surveys (self or proxy) vs caregiver self-report
subject_group <- function(respondent) {
    factor(
        if_else(grepl("^Patient", respondent), "Patient", "Caregiver"),
        levels = c("Patient", "Caregiver")
    )
}

# Axis breaks for counts: whole numbers only (no "0.5 consents")
integer_breaks <- function(limits) {
    breaks <- pretty(limits)
    breaks <- breaks[breaks == round(breaks)]
    if (length(breaks) < 2) breaks <- seq(floor(limits[1]), ceiling(limits[2]))
    breaks
}

# Age in bands, so exact ages never appear on the published site
age_band <- function(age) {
    cut(
        age,
        breaks = c(-Inf, 49, 64, 74, 84, Inf),
        labels = c("Under 50", "50-64", "65-74", "75-84", "85 and older")
    )
}

# Shared ggplotly wrapper: hover text only, axes locked like the DETECT Tool
# plots, and the plotly toolbar trimmed.
as_dashboard_plotly <- function(gg, legend = TRUE) {
    ggplotly(gg, tooltip = c("text")) %>%
        layout(
            xaxis = list(fixedrange = TRUE),
            yaxis = list(fixedrange = TRUE),
            showlegend = legend,
            legend = list(orientation = "h", y = -0.15)
        ) %>%
        config(displaylogo = FALSE, modeBarButtonsToRemove = c("lasso2d", "select2d"))
}

empty_plot <- function(message = "No consent responses yet") {
    plot_ly() %>%
        layout(
            xaxis = list(visible = FALSE),
            yaxis = list(visible = FALSE),
            annotations = list(
                text = message, showarrow = FALSE,
                font = list(color = "#6c757d", size = 14)
            )
        ) %>%
        config(displayModeBar = FALSE)
}

# --- Sidebar boxes (same look as the DETECT Tool sidebar) -------------------------

sidebar_box <- function(names, values, header) {
    data.frame(names = names, values = values) %>%
        flextable() %>%
        delete_part(part = "header") %>%
        bold(j = 1, part = "body") %>%
        border_remove() %>%
        width(j = c(1, 2), width = c(1.2, 1.3), unit = "in") %>%
        add_header_lines(header) %>%
        color(j = c(1, 2), color = "#6c757d", part = "body") %>%
        color(i = c(1), color = "#6c757d", part = "header") %>%
        bg(bg = "#ffffff", part = "body") %>%
        hline(part = "body", border = fp_border(color = "#f3f3f3")) %>%
        height_all(height = 0.5, unit = "in") %>%
        hrule(rule = "exact")
}

sidebar_files_box <- function(file_name, updated_date) {
    sidebar_box(
        names = c("File Name", "Last Updated"),
        values = c(
            file_name,
            if (is.na(updated_date)) "—" else format(updated_date, "%Y-%m-%d")
        ),
        header = "This dashboard displays statistics for:\n\n"
    )
}

sidebar_refs_box <- function(df) {
    dates <- df$consent_date[!is.na(df$consent_date)]
    sidebar_box(
        names = c("Consent Forms", "Consented", "Sites", "Time Period"),
        values = c(
            nrow(df),
            sum(df$consented),
            n_distinct(df$site_short[!is.na(df$site_short)]),
            if (length(dates) == 0) "—" else paste(min(dates), "to", max(dates))
        ),
        header = "This data references:\n\n"
    )
}

# --- Value box numbers ------------------------------------------------------------

consent_counts <- function(df) {
    consented <- df %>% filter(consented)
    dyads <- consented %>%
        filter(!is.na(admin_dyad), admin_dyad != "") %>%
        group_by(admin_dyad) %>%
        summarise(
            has_patient = any(role_f %in% "Patient"),
            has_caregiver = any(role_f %in% "Caregiver"),
            .groups = "drop"
        )
    list(
        started = nrow(df),
        consented = nrow(consented),
        declined = sum(df$consent_f == "Declined"),
        incomplete = sum(df$consent_f == "Incomplete"),
        rate = pct(nrow(consented), sum(df$consent_f != "Incomplete")),
        patients = sum(consented$role_f %in% "Patient"),
        caregivers = sum(consented$role_f %in% "Caregiver"),
        proxy = sum(consented$is_proxy),
        followup = sum(consented$followup_f %in% "Yes"),
        dyads_complete = sum(dyads$has_patient & dyads$has_caregiver),
        surveys_complete = sum(consented$end_status == "Complete")
    )
}

# --- Plots --------------------------------------------------------------------------

# Cumulative consents by role, counted by week of signature
consents_over_time_plot <- function(df) {
    d <- df %>% filter(consented, !is.na(consent_date), !is.na(role_f))
    if (nrow(d) == 0) return(empty_plot())

    weekly <- d %>%
        mutate(week = lubridate::floor_date(consent_date, "week", week_start = 1)) %>%
        count(role_f, week) %>%
        complete(role_f, week, fill = list(n = 0)) %>%
        arrange(week) %>%
        group_by(role_f) %>%
        mutate(total = cumsum(n)) %>%
        ungroup()

    gg <- ggplot(
        weekly,
        aes(
            x = week, y = total, color = role_f, group = role_f,
            text = paste0(
                role_f, "\nWeek of ", format(week, "%b %d, %Y"),
                "\nNew consents: ", n, "\nTotal: ", total
            )
        )
    ) +
        geom_line(linewidth = 0.7) +
        geom_point(size = 1.5) +
        scale_color_manual(values = role_colors, drop = FALSE) +
        xlab("Week Consent Signed") +
        scale_y_continuous(breaks = integer_breaks) +
        ylab("Total Consented") +
        labs(color = "Role") +
        theme_classic()

    as_dashboard_plotly(gg)
}

# Records whose site was never set (admin_institution left at its default of
# 0) are grouped under this label on the All page instead of being dropped.
site_missing_label <- "Site not recorded"

with_site_missing <- function(df) {
    df %>%
        mutate(site_short = factor(
            if_else(is.na(site_short), site_missing_label, as.character(site_short)),
            levels = c(unname(institution_short), site_missing_label)
        ))
}

# --- Record issue banners ------------------------------------------------------
# Two banners at the top of each page, with no overlap:
#   red    -- incomplete consent form from someone who said Yes to taking part
#             or to a follow-up interview: a person to contact.
#   yellow -- every other record with a problem (consent survey not submitted
#             without a Yes, or missing site / role): data to look into.
# Both show counts only (no record IDs or names), and write nothing when there
# is nothing to flag.

# Missing information on each record, as a list of short descriptions
record_missing_info <- function(df) {
    lapply(seq_len(nrow(df)), function(i) {
        r <- df[i, ]
        c(
            if (is.na(r$site_short)) "no site recorded",
            if (r$consented && is.na(r$role_f)) "no role (patient/caregiver) recorded"
        )
    })
}

# Red-banner records: incomplete, but said Yes to consent or follow-up
needs_followup <- function(df) {
    df$consent_f == "Incomplete" & (df$consent_yes | df$followup_f %in% "Yes")
}

banner_html <- function(class, icon, headline, body) {
    cat(sprintf(
        paste0('<div class="reflection-banner %s" role="alert">',
               '<i class="bi %s" aria-hidden="true"></i>',
               '<span><strong>%s</strong> %s</span></div>'),
        class, icon, headline, body
    ))
}

followup_needed_banner <- function(df) {
    ids <- df$admin_record_id[needs_followup(df)]
    if (length(ids) == 0) return(invisible(NULL))
    banner_html(
        "followup-banner", "bi-flag-fill",
        "Incomplete, but interested in consent or follow-up:",
        paste0(length(ids), if (length(ids) == 1) " record." else " records.")
    )
}

record_issues_banner <- function(df) {
    d <- df[!needs_followup(df), ]
    has_issue <- d$consent_f == "Incomplete" | lengths(record_missing_info(d)) > 0
    n <- sum(has_issue)
    if (n == 0) return(invisible(NULL))
    banner_html(
        "", "bi-exclamation-triangle-fill",
        sprintf("%d %s incomplete:", n, if (n == 1) "record" else "records"),
        "missing / responded no to consent and/or follow-up."
    )
}

# Consent decisions by site (All page)
consents_by_site_plot <- function(df) {
    d <- with_site_missing(df)
    if (nrow(d) == 0) return(empty_plot())

    counts <- d %>%
        count(site_short, consent_f, .drop = FALSE) %>%
        # Show the "Site not recorded" bar only when there are such records
        filter(site_short != site_missing_label | any(is.na(df$site_short))) %>%
        group_by(site_short) %>%
        mutate(perc = pct_vec(n)) %>%
        ungroup()

    gg <- ggplot(
        counts,
        aes(
            x = n, y = site_short, fill = consent_f,
            text = paste0(site_short, "\n", consent_f, ": ", n, "\nProportion: ", perc)
        )
    ) +
        geom_bar(stat = "identity", color = "#ffffff", linewidth = 0.3) +
        scale_fill_manual(values = consent_colors, drop = FALSE) +
        scale_y_discrete(limits = rev) +
        labs(fill = "Consent Decision") +
        scale_x_continuous(breaks = integer_breaks) +
        theme_classic() +
        theme(axis.title.x = element_blank(), axis.title.y = element_blank())

    as_dashboard_plotly(gg)
}

# Proportion of each group's total, as "42%"
pct_vec <- function(n) {
    total <- sum(n)
    if (total == 0) rep("—", length(n)) else paste0(round(100 * n / total), "%")
}

# Form status for each instrument among consented participants. Caregiver
# Questions is only counted for caregiver-role participants.
completion_data <- function(df) {
    df %>%
        filter(consented) %>%
        select(role_f, ends_with("_status")) %>%
        pivot_longer(-role_f, names_to = "form", values_to = "status") %>%
        mutate(form = sub("_status$", "", form)) %>%
        filter(!(form == "caregiver_questions" & !role_f %in% "Caregiver")) %>%
        mutate(
            instrument = factor(instrument_labels[form], levels = unname(instrument_labels)),
            status = factor(status, levels = names(status_colors))
        ) %>%
        count(instrument, status, .drop = FALSE) %>%
        group_by(instrument) %>%
        mutate(perc = pct_vec(n)) %>%
        ungroup()
}

completion_plot <- function(df) {
    d <- completion_data(df)
    if (sum(d$n) == 0) return(empty_plot())

    gg <- ggplot(
        d,
        aes(
            x = n, y = instrument, fill = status,
            text = paste0(instrument, "\n", status, ": ", n, "\nProportion: ", perc)
        )
    ) +
        geom_bar(stat = "identity", color = "#ffffff", linewidth = 0.3) +
        scale_fill_manual(values = status_colors, drop = FALSE) +
        scale_y_discrete(limits = rev) +
        labs(fill = "Form Status") +
        scale_x_continuous(breaks = integer_breaks) +
        theme_classic() +
        theme(axis.title.x = element_blank(), axis.title.y = element_blank())

    as_dashboard_plotly(gg)
}

completion_table <- function(df) {
    d <- completion_data(df) %>%
        select(instrument, status, n, perc) %>%
        add_shade_column_x_rows(length(status_colors))
    shaded_datatable(d, c("Instrument", "Form Status", "N", "Proportion"))
}

# Counts of ticked boxes for a checkbox field (columns <prefix>___<code>)
checkbox_counts <- function(df, prefix, labels) {
    cols <- paste0(prefix, "___", names(labels))
    present <- cols %in% names(df)
    tibble(
        label = factor(unname(labels)[present], levels = rev(unique(unname(labels)))),
        n = vapply(cols[present], function(col) sum(df[[col]] %in% c(1, TRUE)), numeric(1)),
        denom = nrow(df)
    ) %>%
        mutate(perc = if_else(denom == 0, "—", paste0(round(100 * n / denom), "%")))
}

# Single-series horizontal bar chart (no legend: the card title names it)
single_bar_plot <- function(counts, empty_message = "No responses yet") {
    if (nrow(counts) == 0 || sum(counts$n) == 0) return(empty_plot(empty_message))

    gg <- ggplot(
        counts,
        aes(
            x = n, y = label,
            text = paste0(label, "\nCount: ", n, "\nProportion: ", perc)
        )
    ) +
        geom_bar(stat = "identity", fill = single_color, width = 0.7) +
        scale_x_continuous(breaks = integer_breaks) +
        theme_classic() +
        theme(axis.title.x = element_blank(), axis.title.y = element_blank())

    as_dashboard_plotly(gg, legend = FALSE)
}

# Caregiver-reported diagnoses of the care recipient (caregivers only)
adrd_plot <- function(df) {
    d <- df %>% filter(consented, role_f %in% "Caregiver")
    single_bar_plot(checkbox_counts(d, "sode_adrd", adrd_labels), "No caregiver responses yet")
}

# Preferred follow-up interview contact times (those interested only)
followup_time_plot <- function(df) {
    d <- df %>% filter(consented, followup_f %in% "Yes")
    single_bar_plot(checkbox_counts(d, "admin_qual_time", qual_time_labels), "No follow-up interest yet")
}

# Caregiver proxy's relationship to the care recipient
relationship_plot <- function(df) {
    d <- df %>% filter(consented, is_proxy, !is.na(relationship_f))
    counts <- d %>%
        count(label = relationship_f) %>%
        mutate(
            perc = pct_vec(n),
            label = factor(label, levels = rev(unname(relationship_labels)))
        )
    single_bar_plot(counts, "No proxy surveys yet")
}

# --- Demographics -------------------------------------------------------------------
# Answers describe the survey's subject: patients (self-report or caregiver
# proxy) and caregivers (self-report). Percentages are within each group.

demographic_items <- list(
    sex_f = "Biological Sex",
    hispanic_f = "Hispanic, Latino/a, or Spanish Origin",
    age_band = "Age",
    marital_f = "Marital Status",
    school_f = "Highest Level of Schooling",
    income_f = "Household Income",
    military_f = "Military Service"
)

demographic_counts <- function(df, var) {
    d <- df %>%
        filter(consented, !is.na(respondent_f)) %>%
        mutate(group = subject_group(respondent_f), age_band = age_band(age))
    d %>%
        filter(!is.na(.data[[var]])) %>%
        count(group, label = .data[[var]], .drop = FALSE) %>%
        group_by(group) %>%
        mutate(perc = pct_vec(n)) %>%
        ungroup()
}

race_counts <- function(df) {
    d <- df %>%
        filter(consented, !is.na(respondent_f)) %>%
        mutate(group = subject_group(respondent_f))
    bind_rows(lapply(levels(d$group), function(g) {
        checkbox_counts(d %>% filter(group == g), "race", race_labels) %>%
            mutate(group = factor(g, levels = levels(d$group)))
    }))
}

grouped_bar_plot <- function(counts) {
    if (nrow(counts) == 0 || sum(counts$n) == 0) return(empty_plot("No responses yet"))

    gg <- ggplot(
        counts,
        aes(
            x = n, y = label, fill = group,
            text = paste0(group, "\n", label, "\nCount: ", n, "\nProportion: ", perc)
        )
    ) +
        geom_bar(
            stat = "identity",
            position = position_dodge2(preserve = "single", padding = 0.15),
            width = 0.8
        ) +
        scale_fill_manual(values = role_colors, drop = FALSE) +
        scale_y_discrete(limits = rev) +
        labs(fill = "Survey About") +
        scale_x_continuous(breaks = integer_breaks) +
        theme_classic() +
        theme(axis.title.x = element_blank(), axis.title.y = element_blank())

    as_dashboard_plotly(gg)
}

demographic_plot <- function(df, var) {
    if (var == "race") return(grouped_bar_plot(race_counts(df) %>% mutate(label = factor(label, levels = rev(levels(label))))))
    grouped_bar_plot(demographic_counts(df, var))
}

# One long table of every demographic item, Patient and Caregiver side by side
demographic_table <- function(df) {
    as_cell <- function(n, perc) paste0(n, " (", perc, ")")
    items <- c(demographic_items[1:2], race = "Race (select all that apply)", demographic_items[-(1:2)])
    rows <- lapply(names(items), function(var) {
        counts <- if (var == "race") race_counts(df) else demographic_counts(df, var)
        if (nrow(counts) == 0) return(NULL)
        counts %>%
            mutate(cell = as_cell(n, perc), characteristic = items[[var]]) %>%
            select(characteristic, label, group, cell) %>%
            pivot_wider(names_from = group, values_from = cell, values_fill = "0 (—)") %>%
            mutate(label = as.character(label))
    })
    d <- bind_rows(rows)
    if (nrow(d) == 0) {
        d <- tibble(characteristic = character(), label = character(), Patient = character(), Caregiver = character())
    }
    for (g in c("Patient", "Caregiver")) if (!g %in% names(d)) d[[g]] <- "0 (—)"
    d <- d %>%
        select(characteristic, label, Patient, Caregiver) %>%
        group_by(characteristic) %>%
        mutate(shade_col = (cur_group_id() %% 2 == 0) * 1) %>%
        ungroup() %>%
        relocate(shade_col)
    shaded_datatable(d, c("Characteristic", "Response", "Patient N (%)", "Caregiver N (%)"))
}

# --- Tables ---------------------------------------------------------------------------

# DT table with the DETECT Tool's grey row-group shading (needs a shade_col)
shaded_datatable <- function(d, colnames) {
    DT::datatable(
        d,
        rownames = FALSE,
        class = list(stripe = FALSE),
        options = list(
            autoWidth = TRUE,
            pageLength = 25,
            columnDefs = list(list(visible = FALSE, targets = 0))
        ),
        colnames = c("Shade column", colnames),
        filter = list(position = "top", clear = FALSE)
    ) %>%
        formatStyle(
            "shade_col",
            target = "row",
            backgroundColor = styleEqual(c(0, 1), c("transparent", "#EEEEEE"))
        )
}

site_table <- function(df) {
    d <- with_site_missing(df) %>%
        group_by(Site = site_short, .drop = FALSE) %>%
        summarise(
            started = n(),
            consented = sum(consented),
            declined = sum(consent_f == "Declined"),
            incomplete = sum(consent_f == "Incomplete"),
            patients = sum(consented & role_f %in% "Patient"),
            caregivers = sum(consented & role_f %in% "Caregiver"),
            proxy = sum(consented & is_proxy),
            complete = sum(consented & end_status == "Complete"),
            .groups = "drop"
        ) %>%
        filter(Site != site_missing_label | started > 0) %>%
        mutate(rate = mapply(pct, consented, started - incomplete)) %>%
        select(Site, started, consented, declined, incomplete, rate, patients, caregivers, proxy, complete) %>%
        add_shade_column_x_rows(1)
    shaded_datatable(
        d,
        c("Site", "Consent Forms", "Consented", "Declined", "Incomplete", "Consent Rate",
          "Patients", "Caregivers", "Proxy Surveys", "Surveys Completed")
    )
}
