# set output directory
if (Sys.info()['sysname'] == "Windows") {
    f <- "U:/"
} else if (Sys.info()['sysname'] == "Darwin") { # macOS
    f <- "/Volumes/brgulbis/"
}

if (!dir.exists(f)) {
    stop("Network drive not available.")
}

# rmarkdown::render(
#     input = "report/daily_dashboard_cvicu.Rmd",
#     output_file = "dashboard_cvicu.html",
#     output_dir = f
# )

rmarkdown::render(
    input = "report/daily_dashboard_hfimu.Rmd",
    output_file = "dashboard_cvicu.html",
    output_dir = f
)

rmarkdown::render(
    input = "report/daily_dashboard_ccu.Rmd",
    output_file = "dashboard_ccu.html",
    output_dir = f
)

if (as_date(file.info(file_nm)$mtime) < today()) {
    warning("Data from previous day")
}

file_nm <- paste0(f, "Data/patient_dashboard/dashboard_data_daily.xlsx")

message(paste("Data updated:", format(file.info(file_nm)$mtime, "%B %d, %Y at %I:%M %p")))
