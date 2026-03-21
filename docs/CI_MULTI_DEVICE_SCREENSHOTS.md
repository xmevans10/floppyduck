# Multi-Device Screenshot CI

> The GitHub App doesn't have `workflows` permission, so this change can't be
> pushed via automation. Apply manually when ready.

## What to Change

In `.github/workflows/ci.yml`, update the `screenshots` job to use a matrix strategy
that runs on multiple simulator sizes. This produces App Store–ready screenshots at
the required display sizes.

### Replace the job header:

```yaml
  screenshots:
    name: Screenshots (${{ matrix.device }})
    runs-on: macos-15
    timeout-minutes: 25
    needs: build-and-test

    strategy:
      fail-fast: false
      matrix:
        include:
          - device: "iPhone 16 Pro Max"
            artifact_suffix: "6_7in"
          - device: "iPhone 16 Pro"
            artifact_suffix: "6_1in"
          - device: "iPhone SE (3rd generation)"
            artifact_suffix: "4_7in"
```

### Update all references to the device name:

Replace hardcoded `"iPhone 16 Pro"` with `${{ matrix.device }}` in:
- `Boot Simulator` step (simctl boot + status_bar)
- `Run Screenshot Tests` step (xcodebuild destination)

### Update artifact names:

- `app-screenshots` → `screenshots-${{ matrix.artifact_suffix }}`
- `test-results` → `test-results-${{ matrix.artifact_suffix }}`
- PR comment header → include `${{ matrix.device }}`

## Why

- App Store requires screenshots at 6.7" (iPhone Pro Max class)
- Captures layout at both large and small extremes
- Runs in parallel so total CI time stays ~25min
