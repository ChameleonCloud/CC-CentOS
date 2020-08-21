if [ $DIB_RELEASE == "7" ]; then
    export DEFAULT_PYTHON_VERSION=$(echo $(python2 --version 2>&1) | awk -F" " '{ print $2}')
elif [ $DIB_RELEASE == "8" ]; then
    export DEFAULT_PYTHON_VERSION=$(echo $(python3 --version 2>&1) | awk -F" " '{ print $2}')
else
    export DEFAULT_PYTHON_VERSION=$(echo $(python --version 2>&1) | awk -F" " '{ print $2}')
fi

