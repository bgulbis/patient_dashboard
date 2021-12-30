rmarkdown::render(
    input = "report/daily_dashboard_cvicu.Rmd",
    output_file = "dashboard_cvicu.html",
    output_dir = "U:/"
    # output_dir = "/Volumes/brgulbis/"
)

rmarkdown::render(
    input = "report/daily_dashboard_ccu.Rmd",
    output_file = "dashboard_ccu.html",
    output_dir = "U:/"
    # output_dir = "/Volumes/brgulbis/"
)
