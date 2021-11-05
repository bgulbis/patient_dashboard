rmarkdown::render(
    input = "report/daily_dashboard_cvicu.Rmd",
    output_file = "dashboard_cvicu.html",
    output_dir = "/Users/briangulbis/Share/U"
)

# mount_smbfs //brgulbis@tmcisilon/user$/user1/brgulbis /Users/briangulbis/Share/U
# mount_smbfs //brgulbis@mh.org/public /Users/briangulbis/Share/W
