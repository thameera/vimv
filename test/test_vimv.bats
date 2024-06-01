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
