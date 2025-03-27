
#!/bin/bash

if command -v jazzy &> /dev/null; then
    echo "Building docs with jazzy"
    # gitlab ci config usually exports ios version to grab a simulator id
    # but default to a recent iOS version to allow for running on dev machines without setting this
    IOS_VERSION=${IOS_VERSION:-17}
    echo "Using iOS version $IOS_VERSION"
    SIMULATOR_ID=`xcrun simctl list -j devices available | jq -r '.devices | to_entries[] | select(.key | contains("com.apple.CoreSimulator.SimRuntime.iOS-'$IOS_VERSION'")) | select(.value != []) | .value[0].udid' | head -1`
    echo "Using simulator id $SIMULATOR_ID"
    if [ -z "${SIMULATOR_ID}" ]; then
        echo "No simulator found for ios version. Exiting"
        exit 1  
    fi
    # Jazzy command line option `--build-tool-arguments` does not accept commas which prevents us from passing a simulator destination of
    # "platform=iOS Simulator,id=abc123". The yaml config approach does not have this issue so this uses a template and injects a simulator id at runtime
    sed -e "s/%%SIMULATOR_ID%%/${SIMULATOR_ID}/g" .jazzy.yaml.template > .jazzy.yaml
    jazzy
    rm .jazzy.yaml
else
    echo "Jazzy is not installed. Skipping docs."
fi
