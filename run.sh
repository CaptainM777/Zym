while [ 1 ]; do 
  bundle exec thor geode -s
  if [ $? -eq 2 ]; then
    break
  fi
done