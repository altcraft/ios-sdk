echo '-----OCLint start-----'
WORKSPACE=HiAnalytics.xcworkspace
SCHEME=HiAnalytics
xcodebuild -workspace $WORKSPACE -scheme $SCHEME clean&&
xcodebuild -workspace $WORKSPACE -scheme $SCHEME \
-configuration Debug \
| xcpretty -r json-compilation-database -o compile_commands.json&&
oclint-json-compilation-database -e Pods -e HAEventType.h -- \
-report-type html -o oclint_result.html \
-rc LONG_LINE=300 \
-rc LONG_METHOD=100 \
-rc LONG_VARIABLE_NAME=25 \
-rc CYCLOMATIC_COMPLEXITY=15 \
-max-priority-1=100000 \
-max-priority-2=100000 \
-max-priority-3=100000; \
rm compile_commands.json;
if [ -f ./oclint_result.html ];
then echo '-----OCLint finish-----'
else echo "-----OCLint fail-----";
fi
