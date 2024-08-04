library(lubridate)

# set output directory
if (Sys.info()['sysname'] == "Windows") {
    f <- "U:/"
} else if (Sys.info()['sysname'] == "Darwin") { # macOS
    f <- "/Volumes/brgulbis/"
}

if (!dir.exists(f)) {
    stop("Network drive not available.")
}

if (Sys.info()['sysname'] == "Windows") {
    file_nm <- "U:/Data/patient_dashboard/dashboard_data_daily.xlsx"
} else if (Sys.info()['sysname'] == "Darwin") { # macOS
    f <- "/Volumes/brgulbis/Data/patient_dashboard/dashboard_data_daily.xlsx"
}

if (as_date(file.info(file_nm)$mtime) < today()) {
    stop("Data from previous day")
} else if (as_datetime(file.info(paste0(f, "dashboard_cvicu.html"))$mtime) > as_datetime(file.info(file_nm)$mtime)) {
    stop(paste("Dashboard data out-of-date. Last updated:", format(file.info(file_nm)$mtime, "%B %d, %Y at %I:%M %p")))
}

rmarkdown::render(
    input = "report/daily_dashboard_cvicu.Rmd",
    output_file = "dashboard_cvicu.html",
    output_dir = f
)

rmarkdown::render(
    input = "report/daily_dashboard_ccu.Rmd",
    output_file = "dashboard_ccu.html",
    output_dir = f
)

rmarkdown::render(
    input = "report/daily_dashboard_hficu.Rmd",
    output_file = "dashboard_hficu.html",
    output_dir = f
)

# rmarkdown::render(
#     input = "report/daily_dashboard_cvimu.Rmd",
#     output_file = "dashboard_cvimu.html",
#     output_dir = f
# )

# rmarkdown::render(
#     input = "report/daily_dashboard_cimu.Rmd",
#     output_file = "dashboard_cimu.html",
#     output_dir = f
# )

# rmarkdown::render(
#     input = "report/daily_dashboard_hfimu.Rmd",
#     output_file = "dashboard_hfimu.html",
#     output_dir = f
# )

message(paste("Data updated:", format(file.info(file_nm)$mtime, "%B %d, %Y at %I:%M %p")))
