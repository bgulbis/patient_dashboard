# set output directory
if (Sys.info()['sysname'] == "Windows") {
    f <- "U:/"
} else if (Sys.info()['sysname'] == "Darwin") { # macOS
    f <- "/Volumes/brgulbis/"
}

if (!dir.exists(f)) {
    stop("Network drive not available.")
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
