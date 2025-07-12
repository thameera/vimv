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
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "Basic renaming" {
  touch file1 file2

  # A mock EDITOR that renames file1 to renamed_file1 and file2 to renamed_file2
  MOCK_EDITOR=$(cat <<EOF
#!/usr/bin/env bash
sed -i '' -e 's/file1/renamed_file1/g' -e 's/file2/renamed_file2/g' \$1
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

  MOCK_EDITOR=$(cat <<EOF
#!/usr/bin/env bash
sed -i '' -e 's/^/renamed_/g' \$1
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

  MOCK_EDITOR=$(cat <<EOF
#!/usr/bin/env bash
sed -i '' -e 's/file1/dir1\/renamed_file1/g' -e 's/file2/dir2\/subdir\/renamed_file2/g' \$1
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
  
  MOCK_EDITOR=$(cat <<EOF
#!/usr/bin/env bash
sed -i '' -e 's/git_tracked_file1/renamed_git_file1/g' -e 's/git_tracked_file2/renamed_git_file2/g' -e 's/untracked_file/renamed_untracked_file/g' \$1
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

  MOCK_EDITOR=$(cat <<EOF
#!/usr/bin/env bash
# Rename both files to the same name → duplicates
sed -i '' -e 's/file1/dup/g' -e 's/file2/dup/g' \$1
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
