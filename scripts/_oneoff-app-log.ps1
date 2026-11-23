# app/main.ch: replace the startup printf calls with the core logger, and finish
# the remaining pointer/field accesses.
$p = 'D:\Programming\Wiqis\Web\underlayer\app\main.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")

$t = $t.Replace(
'    printf("[underlayer] Starting Underlayer on port %s\n", underlayer_core::u32_to_string(port).data())',
@'
    var start_msg = std::string("[underlayer] Starting Underlayer on port ")
    start_msg.append_string(&underlayer_core::u32_to_string(port))
    underlayer_core::log_line(&start_msg)
'@.Replace("`r`n","`n"))

$t = $t.Replace(
@'
        printf("%s", fatal.data())
        fflush(stdout)
'@.Replace("`r`n","`n"),
@'
        underlayer_core::log_line(&fatal)
'@.Replace("`r`n","`n"))

$t = $t.Replace(
'    printf("[underlayer] Database OK: %s\n", db_url.data())',
@'
    var ok_msg = std::string("[underlayer] Database OK: ")
    ok_msg.append_string(&db_url)
    underlayer_core::log_line(&ok_msg)
'@.Replace("`r`n","`n"))

$t = $t.Replace(
'            printf("[underlayer] Seeded %s exercises from manifests\n", underlayer_core::int_to_string(seeded_total).data())',
@'
            var seed_msg = std::string("[underlayer] Seeded ")
            seed_msg.append_string(&underlayer_core::int_to_string(seeded_total))
            seed_msg.append_view(" exercises from manifests")
            underlayer_core::log_line(&seed_msg)
'@.Replace("`r`n","`n"))

$t = $t.Replace(
'    printf("[underlayer] Server running at http://localhost:%s\n", underlayer_core::u32_to_string(port).data())',
@'
    var listen_msg = std::string("[underlayer] Server running at http://localhost:")
    listen_msg.append_string(&underlayer_core::u32_to_string(port))
    underlayer_core::log_line(&listen_msg)
'@.Replace("`r`n","`n"))

$t = $t.Replace(
'    printf("[underlayer] Courses dir: %s\n", cfg.courses_dir.data())',
@'
    var courses_msg = std::string("[underlayer] Courses dir: ")
    courses_msg.append_string(&cfg.courses_dir)
    underlayer_core::log_line(&courses_msg)
'@.Replace("`r`n","`n"))

# `var cid = cptr.id.copy()` where cptr came from get_ptr.
$t = $t.Replace('            var cptr = all_courses.at_ref(ci)' + "`n" + '            var cid = cptr.id.copy()',
                '            var cptr = all_courses.at_ref(ci)' + "`n" + '            var cid = cptr.id.copy()')

[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'startup logging converted'
