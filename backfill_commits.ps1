# backfill_commits.ps1
# Fills GitHub contribution graph with realistic backdated commits.
# Run once from the repo root. Requires git to be in PATH.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot

# --------------------------------------------------------------------------- #
#  Config
# --------------------------------------------------------------------------- #
$startDate  = [datetime]"2026-03-30"
$endDate    = [datetime]"2026-04-30"
$skipRatio  = 0.10      # 10% of days left empty
$minPerDay  = 5
$maxPerDay  = 10

# --------------------------------------------------------------------------- #
#  Build list of active days (skip ~10% randomly)
# --------------------------------------------------------------------------- #
$allDays = @()
$d = $startDate
while ($d -le $endDate) {
    $allDays += $d
    $d = $d.AddDays(1)
}

$rng = [System.Random]::new()
$skipCount = [int][Math]::Round($allDays.Count * $skipRatio)
$skipIndices = @()
while ($skipIndices.Count -lt $skipCount) {
    $idx = $rng.Next(0, $allDays.Count)
    if ($idx -notin $skipIndices) { $skipIndices += $idx }
}

$activeDays = @()
for ($i = 0; $i -lt $allDays.Count; $i++) {
    if ($i -notin $skipIndices) { $activeDays += $allDays[$i] }
}

Write-Host "Active days: $($activeDays.Count)  Skipped: $skipCount" -ForegroundColor Cyan
Write-Host "Skipped dates: $(($skipIndices | ForEach-Object { $allDays[$_].ToString('MMM dd') }) -join ', ')" -ForegroundColor DarkYellow

# --------------------------------------------------------------------------- #
#  Commit message pool (realistic for a C++ student project)
# --------------------------------------------------------------------------- #
$messages = @(
    "fix: remove trailing whitespace",
    "style: apply consistent brace formatting",
    "refactor: rename local var for clarity",
    "chore: add missing newline at end of file",
    "fix: correct comment wording",
    "style: align printf format strings",
    "refactor: extract magic number to named constant",
    "chore: clean up unused include",
    "fix: improve error message text",
    "docs: update inline comment accuracy",
    "style: normalize indentation in switch block",
    "refactor: simplify boolean condition",
    "fix: add const qualifier where appropriate",
    "chore: reorder includes alphabetically",
    "style: wrap long line for readability",
    "fix: correct off-by-one in loop bound comment",
    "refactor: move declaration closer to use",
    "docs: clarify semaphore usage in comment",
    "chore: remove redundant blank line",
    "fix: use explicit cast to silence warning",
    "style: unify spacing around operators",
    "refactor: inline trivial helper expression",
    "chore: add TODO note for edge case",
    "fix: guard against negative index",
    "docs: document producer exit condition",
    "style: reformat multi-line function call",
    "chore: update Makefile comment",
    "fix: correct type in printf format",
    "refactor: extract dispatch condition to variable",
    "docs: add brief description to struct fields",
    "style: remove double blank line",
    "fix: ensure sem_destroy called on all paths",
    "chore: minor code cleanup after review",
    "refactor: use pre-increment instead of post",
    "fix: adjust sleep value for delay mode",
    "docs: note why no_sync skips semaphore",
    "chore: tidy up consumer exit logic comment",
    "style: standardize pointer declaration style",
    "fix: add missing space after keyword",
    "refactor: fold nested if into single condition"
)

# --------------------------------------------------------------------------- #
#  Micro-change functions (real file edits that are self-reversing in cycles)
# --------------------------------------------------------------------------- #

# Pool of actual text mutations applied round-robin so the file stays valid.
# Each entry: [file (relative), search, replace, search_back, replace_back]
# "forward" and "backward" alternating keeps the code compilable.
$mutations = @(
    # --- main.cpp ---
    @{ file="main.cpp"; fwd_find='setbuf(stdout, NULL);'; fwd_rep='setbuf(stdout, nullptr);'; bwd_find='setbuf(stdout, nullptr);'; bwd_rep='setbuf(stdout, NULL);' },
    @{ file="main.cpp"; fwd_find='int no_sync = 0, use_delay = 0, verbose = 0;'; fwd_rep='int no_sync = 0, use_delay = 0, verbose = 0; // cli flags'; bwd_find='int no_sync = 0, use_delay = 0, verbose = 0; // cli flags'; bwd_rep='int no_sync = 0, use_delay = 0, verbose = 0;' },
    @{ file="main.cpp"; fwd_find='int counts[3] = {0, 0, 0};'; fwd_rep='int counts[3] = {0, 0, 0}; // optional element counts'; bwd_find='int counts[3] = {0, 0, 0}; // optional element counts'; bwd_rep='int counts[3] = {0, 0, 0};' },
    @{ file="main.cpp"; fwd_find='    int ci = 0;'; fwd_rep='    int ci = 0; // count index'; bwd_find='    int ci = 0; // count index'; bwd_rep='    int ci = 0;' },
    @{ file="main.cpp"; fwd_find='pid_t pids[5];'; fwd_rep='pid_t pids[5]; // 3 producers + 2 consumers'; bwd_find='pid_t pids[5]; // 3 producers + 2 consumers'; bwd_rep='pid_t pids[5];' },
    @{ file="main.cpp"; fwd_find='close(fd);'; fwd_rep='close(fd); // fd no longer needed after mmap'; bwd_find='close(fd); // fd no longer needed after mmap'; bwd_rep='close(fd);' },
    @{ file="main.cpp"; fwd_find='return 0;'; fwd_rep='return EXIT_SUCCESS;'; bwd_find='return EXIT_SUCCESS;'; bwd_rep='return 0;' },
    @{ file="main.cpp"; fwd_find='char types[] = {''A'', ''B'', ''C''};'; fwd_rep='const char types[] = {''A'', ''B'', ''C''};'; bwd_find='const char types[] = {''A'', ''B'', ''C''};'; bwd_rep='char types[] = {''A'', ''B'', ''C''};' },

    # --- workers.cpp ---
    @{ file="workers.cpp"; fwd_find='int ca = 0, cb = 0;'; fwd_rep='int ca = 0, cb = 0; // consumed counts'; bwd_find='int ca = 0, cb = 0; // consumed counts'; bwd_rep='int ca = 0, cb = 0;' },
    @{ file="workers.cpp"; fwd_find='int triples = 0, singles = 0;'; fwd_rep='int triples = 0, singles = 0; // consumer2 stats'; bwd_find='int triples = 0, singles = 0; // consumer2 stats'; bwd_rep='int triples = 0, singles = 0;' },
    @{ file="workers.cpp"; fwd_find='srand(getpid());'; fwd_rep='srand((unsigned)getpid());'; bwd_find='srand((unsigned)getpid());'; bwd_rep='srand(getpid());' },
    @{ file="workers.cpp"; fwd_find='  if (!skip)'; fwd_rep='  if (!skip) // no-op when sync disabled'; bwd_find='  if (!skip) // no-op when sync disabled'; bwd_rep='  if (!skip)' },
    @{ file="workers.cpp"; fwd_find='    return false;'; fwd_rep='    return false; // no C elements available'; bwd_find='    return false; // no C elements available'; bwd_rep='    return false;' },
    @{ file="workers.cpp"; fwd_find='usleep(100 + rand() % 900);'; fwd_rep='usleep(200 + rand() % 800);'; bwd_find='usleep(200 + rand() % 800);'; bwd_rep='usleep(100 + rand() % 900);' },
    @{ file="workers.cpp"; fwd_find='      usleep(500);'; fwd_rep='      usleep(600);'; bwd_find='      usleep(600);'; bwd_rep='      usleep(500);' },

    # --- queue.cpp ---
    @{ file="queue.cpp"; fwd_find='// (any line we can find)'; fwd_rep='// (any line we can find)'; bwd_find='// (any line we can find)'; bwd_rep='// (any line we can find)' },

    # --- Makefile ---
    @{ file="Makefile"; fwd_find='CXXFLAGS'; fwd_rep='CXXFLAGS'; bwd_find='CXXFLAGS'; bwd_rep='CXXFLAGS' },  # no-op placeholder, Makefile handled separately

    # --- element.h ---
    @{ file="element.h"; fwd_find='char type;'; fwd_rep='char type; // A, B or C'; bwd_find='char type; // A, B or C'; bwd_rep='char type;' },

    # --- shared_data.h ---
    @{ file="shared_data.h"; fwd_find='int no_sync;'; fwd_rep='int no_sync; // 1 = semaphores disabled'; bwd_find='int no_sync; // 1 = semaphores disabled'; bwd_rep='int no_sync;' },
    @{ file="shared_data.h"; fwd_find='int use_delay;'; fwd_rep='int use_delay; // 1 = artificial delays enabled'; bwd_find='int use_delay; // 1 = artificial delays enabled'; bwd_rep='int use_delay;' },
    @{ file="shared_data.h"; fwd_find='int verbose;'; fwd_rep='int verbose; // 1 = detailed logging'; bwd_find='int verbose; // 1 = detailed logging'; bwd_rep='int verbose;' }
)

# Remove the dummy queue.cpp / Makefile no-op entries
$mutations = $mutations | Where-Object { $_.fwd_find -ne '// (any line we can find)' -and $_.fwd_find -ne 'CXXFLAGS' }

# Track direction for each mutation (0=forward applied, 1=backward applied)
$mutationState = @(0) * $mutations.Count

function Apply-Mutation {
    param($idx)
    $m = $mutations[$idx]
    $path = Join-Path $repoRoot $m.file
    $content = [System.IO.File]::ReadAllText($path)

    if ($mutationState[$idx] -eq 0) {
        # apply forward
        if ($content.Contains($m.fwd_find)) {
            $newContent = $content.Replace($m.fwd_find, $m.fwd_rep)
            [System.IO.File]::WriteAllText($path, $newContent)
            $mutationState[$idx] = 1
            return $true
        }
    } else {
        # apply backward
        if ($content.Contains($m.bwd_find)) {
            $newContent = $content.Replace($m.bwd_find, $m.bwd_rep)
            [System.IO.File]::WriteAllText($path, $newContent)
            $mutationState[$idx] = 0
            return $true
        }
    }
    return $false
}

# --------------------------------------------------------------------------- #
#  Main loop
# --------------------------------------------------------------------------- #
$mutIdx = 0  # round-robin index through mutations

foreach ($day in $activeDays) {
    $commitsToday = $rng.Next($minPerDay, $maxPerDay + 1)
    Write-Host "`n[$($day.ToString('yyyy-MM-dd'))] -> $commitsToday commits" -ForegroundColor Green

    for ($c = 0; $c -lt $commitsToday; $c++) {
        # Random time between 09:00 and 23:30
        $hour   = $rng.Next(9, 24)
        $minute = $rng.Next(0, 60)
        $second = $rng.Next(0, 60)
        $commitDt = $day.AddHours($hour).AddMinutes($minute).AddSeconds($second)
        # ISO 8601 with +0200 (Warsaw summer time)
        $dateStr = $commitDt.ToString("yyyy-MM-dd HH:mm:ss") + " +0200"

        # Pick a mutation and apply it
        $applied = $false
        $tries = 0
        while (-not $applied -and $tries -lt $mutations.Count) {
            $applied = Apply-Mutation -idx ($mutIdx % $mutations.Count)
            $mutIdx++
            $tries++
        }

        if (-not $applied) {
            Write-Warning "Could not apply any mutation for commit $c on $($day.ToString('yyyy-MM-dd')), skipping."
            continue
        }

        # Pick a commit message
        $msg = $messages[$rng.Next(0, $messages.Count)]

        # Stage and commit with backdated timestamp
        $env:GIT_AUTHOR_DATE    = $dateStr
        $env:GIT_COMMITTER_DATE = $dateStr

        Push-Location $repoRoot
        git add -A | Out-Null
        git commit -m $msg | Out-Null
        Pop-Location

        Write-Host "  [$($commitDt.ToString('HH:mm'))] $msg" -ForegroundColor DarkGray
    }
}

# Cleanup env vars
Remove-Item Env:\GIT_AUTHOR_DATE    -ErrorAction SilentlyContinue
Remove-Item Env:\GIT_COMMITTER_DATE -ErrorAction SilentlyContinue

Write-Host "`nDone! Push with: git push origin main" -ForegroundColor Cyan
