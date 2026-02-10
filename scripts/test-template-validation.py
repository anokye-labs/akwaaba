#!/usr/bin/env python3
"""
Test script to validate the regex patterns used in issue templates.
This ensures the validation patterns work as expected.
"""

import re
import sys

def test_pattern(name, pattern, valid_inputs, invalid_inputs):
    """Test a regex pattern against valid and invalid inputs."""
    print(f"\n{'='*60}")
    print(f"Testing: {name}")
    print(f"Pattern: {pattern}")
    print(f"{'='*60}")
    
    regex = re.compile(pattern)
    all_passed = True
    
    # Test valid inputs
    print("\n✓ Valid inputs (should match):")
    for test_input in valid_inputs:
        match = regex.match(test_input)
        if match:
            print(f"  ✓ '{test_input}' - PASS")
        else:
            print(f"  ✗ '{test_input}' - FAIL (should match)")
            all_passed = False
    
    # Test invalid inputs
    print("\n✗ Invalid inputs (should NOT match):")
    for test_input in invalid_inputs:
        match = regex.match(test_input)
        if not match:
            print(f"  ✓ '{test_input}' - PASS (correctly rejected)")
        else:
            print(f"  ✗ '{test_input}' - FAIL (should not match)")
            all_passed = False
    
    return all_passed

def main():
    """Run all pattern tests."""
    print("Issue Template Validation Pattern Tests")
    print("="*60)
    
    all_tests_passed = True
    
    # Test 1: Issue Number Pattern
    all_tests_passed &= test_pattern(
        name="Issue Number Pattern",
        pattern=r'^#?\d+$',
        valid_inputs=[
            '1',
            '123',
            '#1',
            '#123',
            '9999',
        ],
        invalid_inputs=[
            '',
            '#',
            'abc',
            '#abc',
            '12a',
            '12 34',
            '12.34',
            '-12',
        ]
    )
    
    # Test 2: GitHub Username Pattern
    all_tests_passed &= test_pattern(
        name="GitHub Username Pattern",
        pattern=r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?$',
        valid_inputs=[
            'copilot',
            'user123',
            'my-bot-name',
            'ABC',
            'a',
            'user-name-with-hyphens',
            'a' + '1'*37 + 'b',  # 39 chars (max valid)
        ],
        invalid_inputs=[
            '',
            '-invalid',
            'invalid-',
            'user name',
            'user@name',
            'user.name',
            'user_name',
            '--invalid',
            'a' + '1'*38 + 'b',  # 40 chars (too long)
        ]
    )
    
    # Test 3: Bot Username Pattern
    all_tests_passed &= test_pattern(
        name="Bot Username Pattern",
        pattern=r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?\[bot\]$',
        valid_inputs=[
            'copilot[bot]',
            'my-app[bot]',
            'github-actions[bot]',
            'a[bot]',
        ],
        invalid_inputs=[
            '',
            'copilot',
            '[bot]',
            'copilot[bot',
            'copilot bot]',
            'copilot-[bot]',
            '-copilot[bot]',
            'copilot[bot]-',
            'copilot[BOT]',
        ]
    )
    
    # Test 4: GitHub App ID Pattern
    all_tests_passed &= test_pattern(
        name="GitHub App ID Pattern",
        pattern=r'^\d+$',
        valid_inputs=[
            '1',
            '12345',
            '999999',
            '0',
        ],
        invalid_inputs=[
            '',
            'abc',
            '123abc',
            'abc123',
            '12.34',
            '-123',
            '12 34',
            '#123',
        ]
    )
    
    # Print summary
    print("\n" + "="*60)
    if all_tests_passed:
        print("✓ ALL TESTS PASSED")
        print("="*60)
        return 0
    else:
        print("✗ SOME TESTS FAILED")
        print("="*60)
        return 1

if __name__ == '__main__':
    sys.exit(main())
