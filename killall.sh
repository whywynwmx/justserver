for pid in $(lsof -t +D "$(pwd)"); do
    kill "$pid"
done
