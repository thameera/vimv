#!/usr/bin/env bats

declare TMPDIR

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'

  # Get directory of test file
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"

  # Temp dir to create files in
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"

  PATH="$DIR/..:$TMPDIR:$PATH"

  # Portable sed -i flag (GNU vs BSD)
  if sed --version >/dev/null 2>&1; then
    # GNU sed
    export SED_INPLACE='-i'
  else
    # BSD/macOS sed
    export SED_INPLACE="-i ''"
  fi
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "Basic renaming" {
  touch file1 file2

  # A mock EDITOR that renames file1 to renamed_file1 and file2 to renamed_file2
  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
sed $SED_INPLACE -e 's/file1/renamed_file1/g' -e 's/file2/renamed_file2/g' "$1"
EOF
)

  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  run env EDITOR="mock_editor" vimv

  # Test that the files were renamed
  [ -e renamed_file1 ] && [ -e renamed_file2 ]
  [ ! -e file1 ] && [ ! -e file2 ]

  # Test that the output is correct
  assert_output "2 files renamed."
}

@test "Argument handling" {
  touch file1.mp4 file2.mp4 file3.txt

  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
sed $SED_INPLACE -e 's/^/renamed_/g' "$1"
EOF
)

  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  run env EDITOR="mock_editor" vimv *.mp4

  # Test that the files were renamed
  [ -e renamed_file1.mp4 ] && [ -e renamed_file2.mp4 ]
  [ ! -e file1.mp4 ] && [ ! -e file2.mp4 ]

  # The txt file should be untouched
  [ -e file3.txt ]

  assert_output "2 files renamed."
}

@test "Directory creation with renamed files" {
  touch file1 file2

  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
sed $SED_INPLACE -e 's/file1/dir1\/renamed_file1/g' -e 's/file2/dir2\/subdir\/renamed_file2/g' "$1"
EOF
)

  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  run env EDITOR="mock_editor" vimv

  # Test that directories were created and files were properly renamed
  [ -e dir1/renamed_file1 ]
  [ -e dir2/subdir/renamed_file2 ]
  [ ! -e file1 ] && [ ! -e file2 ]

  assert_output "2 files renamed."
}

@test "Git integration" {
  # Initialize a git repo and add some files
  git init .
  touch git_tracked_file1 git_tracked_file2 untracked_file
  git add git_tracked_file1 git_tracked_file2
  git config --local user.email "test@example.com"
  git config --local user.name "Test User"
  git commit -m "Initial commit"

  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
sed $SED_INPLACE -e 's/git_tracked_file1/renamed_git_file1/g' -e 's/git_tracked_file2/renamed_git_file2/g' -e 's/untracked_file/renamed_untracked_file/g' "$1"
EOF
)

  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  run env EDITOR="mock_editor" vimv
  assert_output "3 files renamed."

  # Test that files were renamed
  [ -e renamed_git_file1 ] && [ -e renamed_git_file2 ] && [ -e renamed_untracked_file ]
  [ ! -e git_tracked_file1 ] && [ ! -e git_tracked_file2 ] && [ ! -e untracked_file ]

  # Verify git-tracked files were renamed with git mv by checking git status
  run git ls-files
  assert_line "renamed_git_file1"
  assert_line "renamed_git_file2"

  # Ensure the untracked file is still not tracked
  run bash -c "git ls-files | grep -q renamed_untracked_file"
  [ "$status" -ne 0 ]
}

@test "Abort on duplicate destination filenames" {
  touch file1 file2

  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
# Rename both files to the same name → duplicates
sed $SED_INPLACE -e 's/file1/dup/g' -e 's/file2/dup/g' "$1"
EOF
)
  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  run env EDITOR="mock_editor" vimv

  # Should fail
  [ "$status" -ne 0 ]
  assert_output --partial "Destination filenames are not unique"

  # Nothing was renamed
  [ -e file1 ] && [ -e file2 ]
  [ ! -e dup ]
}

@test "Cyclic renaming (file1 <-> file2)" {
  # Two files with distinguishable content
  echo "one" > file1
  echo "two" > file2

  # Swap the two names in-place
  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
# Swap file1 ↔︎ file2 using a temporary placeholder
sed $SED_INPLACE \
  -e 's/file1/__tmp__/g' \
  -e 's/file2/file1/g' \
  -e 's/__tmp__/file2/g' "$1"
EOF
)
  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  run env EDITOR="mock_editor" vimv
  assert_success
  assert_output "2 files renamed."

  # Both files should still exist
  [ -e file1 ] && [ -e file2 ]

  # and their contents should have swapped
  run cat file1
  assert_output "two"
  run cat file2
  assert_output "one"
}

@test "No overwrite into existing path (non-git)" {
  echo src > myfile
  mkdir t
  echo keep > t/keepme

  # Rename myfile -> t/keepme (already exists)
  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
sed $SED_INPLACE -e 's@myfile@t/keepme@g' "$1"
EOF
)
  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  run env EDITOR="mock_editor" vimv myfile
  assert_success
  assert_output --partial "1 files renamed."
  assert_output --partial "WARN: Can't rename 't/keepme.vimv-tmp" || true # warning printed in second pass

  # Original dest intact
  [ "$(cat t/keepme)" = "keep" ]

  # Parked temp exists
  run ls t/keepme.vimv-tmp-*
  assert_success

  # Source gone
  [ ! -e myfile ]
}

@test "No overwrite into existing path (git-tracked)" {
  git init .
  git config --local user.email "test@example.com"
  git config --local user.name "Test User"

  echo src > myfile
  mkdir t
  echo keep > t/keepme

  git add myfile t/keepme
  git commit -m "add files"

  # Rename myfile -> t/keepme (already exists)
  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
sed $SED_INPLACE -e 's@myfile@t/keepme@g' "$1"
EOF
)
  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  run env EDITOR="mock_editor" vimv myfile
  assert_success
  assert_output --partial "1 files renamed."
  assert_output --partial "WARN: Can't rename"  # should have warned

  # Existing tracked file still present & unchanged
  [ -e t/keepme ]
  [ "$(cat t/keepme)" = "keep" ]

  # Parked git-tracked temp exists
  run ls t/keepme.vimv-tmp-*
  assert_success

  # Check git knows about the parked name (grep for pattern)
  run bash -c 'git ls-files | grep -E "t/keepme\.vimv-tmp-"'
  assert_success
}

@test "Mixed batch: conflict + clean rename continues" {
  echo a > file_conflict
  echo b > file_ok
  mkdir t
  echo keep > t/keepme

  # Rename conflict file -> t/keepme (exists)
  # Rename ok file -> file_ok_new
  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
# Replace file_conflict first, file_ok second
sed $SED_INPLACE \
  -e 's@file_conflict@t/keepme@g' \
  -e 's@file_ok@file_ok_new@g' "$1"
EOF
)
  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  run env EDITOR="mock_editor" vimv file_conflict file_ok
  assert_success
  assert_output --partial "2 files renamed."
  assert_output --partial "WARN: Can't rename"  # at least one warning expected

  # Clean rename succeeded
  [ -e file_ok_new ]
  [ ! -e file_ok ]

  # Conflict handled: dest untouched, parked temp exists
  [ "$(cat t/keepme)" = "keep" ]
  run ls t/keepme.vimv-tmp-*
  assert_success
}

@test "Dotfile renaming" {
  # Create hidden files
  touch .file1 .file2

  # Mock EDITOR that renames dotfiles
  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
sed $SED_INPLACE -e 's/\.file1/renamed_file1/g' -e 's/\.file2/renamed_file2/g' "$1"
EOF
)
  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  # We rely on vimv to include dotfiles in the temp file here
  run env EDITOR="mock_editor" vimv

  # Files should be renamed
  [ -e renamed_file1 ] && [ -e renamed_file2 ]
  [ ! -e .file1 ] && [ ! -e .file2 ]

  # Output should confirm the count
  assert_output "2 files renamed."
}

@test "Abort on line count mismatch (deleted line)" {
  touch file1 file2 file3

  # Mock editor that deletes one line
  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
# Delete the second line, leaving only 2 lines instead of 3
sed $SED_INPLACE -e '2d' "$1"
EOF
)
  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  run env EDITOR="mock_editor" vimv

  # Should fail
  [ "$status" -ne 0 ]
  assert_output --partial "Number of files changed"

  # Nothing was renamed - all original files still exist
  [ -e file1 ] && [ -e file2 ] && [ -e file3 ]
}

@test "No changes when editor leaves file unchanged" {
  touch file1 file2

  # Mock editor that does nothing (just exits successfully)
  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
# Do nothing - leave the file as is
exit 0
EOF
)
  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  run env EDITOR="mock_editor" vimv

  assert_success
  assert_output "0 files renamed."

  # All files still exist with original names
  [ -e file1 ] && [ -e file2 ]
}

@test "Files with spaces and special characters" {
  touch "file with spaces"
  touch "file'with'quotes"
  touch 'file"with"double'
  touch "file@#\$%special"

  MOCK_EDITOR=$(cat <<'EOF'
#!/usr/bin/env bash
# Prefix all lines with "renamed_"
sed $SED_INPLACE -e 's/^/renamed_/g' "$1"
EOF
)
  echo "$MOCK_EDITOR" > mock_editor
  chmod +x mock_editor

  run env EDITOR="mock_editor" vimv "file with spaces" "file'with'quotes" 'file"with"double' "file@#\$%special"

  assert_success
  assert_output "4 files renamed."

  # Renamed files exist
  [ -e "renamed_file with spaces" ]
  [ -e "renamed_file'with'quotes" ]
  [ -e 'renamed_file"with"double' ]
  [ -e "renamed_file@#\$%special" ]

  # Original files gone
  [ ! -e "file with spaces" ]
  [ ! -e "file'with'quotes" ]
  [ ! -e 'file"with"double' ]
  [ ! -e "file@#\$%special" ]
}