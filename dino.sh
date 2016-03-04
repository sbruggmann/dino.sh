#!/bin/sh

# Docker Development init for Neos and Flow

TIME_BEFORE=$(date +%s)
CURRENT_VERSION="0.4.8"

BASE_PATH="$PWD"
PROJECT_NAME=$(echo ${PWD##*/} | sed 's/[^a-zA-Z0-9]//g')
PROJECT_MAIN="_main_1"
PROJECT_MAIN_I="_main"
PROJECT_WEB="_web_1"
PROJECT_WEB_I="_web"
PROJECT_MYSQL="_mysql_1"
PROJECT_MYSQL_I="_mysql"
PROJECT_STORAGE="_storage_1"
PROJECT_STORAGE_I="_storage"
PROJECT_SATIS="_satis_1"
PROJECT_SATIS_I="_satis"
PROJECT_MAIL="_mail_1"
PROJECT_MAIL_I="_mail"
DOCKER_IP=$(echo `docker-machine ip default`)
PATCH_VERSION_URL="https://raw.githubusercontent.com/sbruggmann/dino.sh/$CURRENT_VERSION/patch.diff"
if [ -d ./www/Flow ]; then
  PROJECT_TYPE="Flow"
else
  PROJECT_TYPE="Neos"
fi

# settings from .bash_profile
if [ -z $DINO_SETTINGS_OUTPUT ]; then
  DINO_SETTINGS_OUTPUT="verbose"
fi
#if [[ ( "$1" != "reload" && "$1" != "-r" ) ]]; then
#  DINO_SETTINGS_OUTPUT="silent"
#fi
if [ -z $DINO_SETTINGS_MAIL ]; then
  DINO_SETTINGS_MAIL="disabled"
fi
if grep -q "http://satis:80" "./www/$PROJECT_TYPE/composer.json"; then
  DINO_SETTINGS_SATIS="enabled"
else
  DINO_SETTINGS_SATIS="disabled"
fi

spinner()
{
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    echo "$pid" > "/tmp/.spinner.pid"
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "%c " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b"
    done
    printf "    \b\b\b\b"
}

dockerReady()
{
  while ! curl http://$1/
  do
    printf "$(date) "
    sleep 1
  done
}

if [[ "$1" == "help" || "$1" == "-h" ]]; then
  clear
  printf "show help..\n\n\n\n"

  echo "Usage: ./dino.sh [OPTION]..."
  printf "\n\n"
  echo "  -h,  help                        show this help"
  echo "  -v,  version                     show the current version of dino.sh"
  echo " "
  echo "  -r,  reload                      delete and reload containers and images of the project."
  echo "                                   use './dino.sh reload --force' to delete and reload the docker files too."
  echo "  -u,  selfupdate                  download the latest dino.sh"
  echo "                                   run './dino.sh reload' afterwards"
  echo " "
  echo "       bash [root]                 login to docker container as www-data."
  echo "                                   use './dino.sh bash root' to login as root."
  echo "       ssh  [root]                 alias for the './dino.sh bash' command."
  echo " "
  echo "       links                       show symlinks between /docker/www and /docker/host-www"
  echo "       link {path}                 create a symlink"
  echo "       unlink {path}               remove a symlink"
  echo "       copy {path}                 copy data between /docker/www and /docker/host-www"
  echo " "
  echo "       satis [bash, build]         login to satis docker container,"
  echo "                                   or rebuild it directly."
  printf "\n\n"
  exit
fi

if [[ "$1" == "version" || "$1" == "-v" ]]; then
  if [[ "$2" == "tight" || "$2" == "-t" ]]; then
    printf "$CURRENT_VERSION"
    exit
  else
    echo "dino.sh | Version: $CURRENT_VERSION"

    if [ -f ./docker/bin/run.sh ]; then
      chmod +x ./docker/bin/run.sh
      DINO_RUN_VERSION=$(echo `./docker/bin/run.sh version tight`)
      if [[ "$CURRENT_VERSION" != "$DINO_RUN_VERSION" ]]; then
        echo "        | docker Patch is not up to date! ($DINO_RUN_VERSION)"
        echo "        | Please update: ./dino.sh reload --force"
      fi
    fi

    exit
  fi
fi

if [[ "$1" == "settings" ]]; then
  if [[ -z "$2" ]]; then
    printf "\n"
    echo "dino.sh | available settings:"
    echo "dino.sh | ./dino.sh settings output [verbose|silent]"
    echo "dino.sh | ./dino.sh settings mail [enabled|disabled]"
    printf "\n"
  else
    if [[ "$2" == "output" ]]; then
      if [[ -z "$3" ]]; then
        printf "dino.sh | output is %s\n" $DINO_SETTINGS_OUTPUT
      else
        echo "dino.sh | set output $3"
        echo "export DINO_SETTINGS_OUTPUT=\"$3\"" >> ~/.bash_profile
      fi
    fi
    if [[ "$2" == "mail" ]]; then
      if [[ -z "$3" ]]; then
        printf "dino.sh | mail is %s\n" $DINO_SETTINGS_MAIL
      else
        echo "dino.sh | set mail $3"
        echo "export DINO_SETTINGS_MAIL=\"$3\"" >> ~/.bash_profile
      fi
    fi
  fi
  exit
fi

if [[ ( "$1" == "reload" || "$1" == "-r" ) && ( "$2" == "--force") ]]; then
  printf "\n"
  echo "dino.sh | Force-Reload:"
  printf "dino.sh | Delete all docker files, reload container and images? [y] "
  read SAY_OK
  if [[ "$SAY_OK" == "y" ]]; then

    printf "\n"
    if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
      rm -rf docker*; docker rm -f "$PROJECT_NAME$PROJECT_MAIN" "$PROJECT_NAME$PROJECT_WEB" "$PROJECT_NAME$PROJECT_MYSQL" "$PROJECT_NAME$PROJECT_STORAGE" "$PROJECT_NAME$PROJECT_SATIS" "$PROJECT_NAME$PROJECT_MAIL"; docker rmi -f "$PROJECT_NAME$PROJECT_MAIN_I" "$PROJECT_NAME$PROJECT_WEB_I" "$PROJECT_NAME$PROJECT_MYSQL_I" "$PROJECT_NAME$PROJECT_STORAGE_I" "$PROJECT_NAME$PROJECT_SATIS_I" "$PROJECT_NAME$PROJECT_MAIL_I"
    else
      (OUTPUT=`rm -rf docker*; docker rm -f "$PROJECT_NAME$PROJECT_MAIN" "$PROJECT_NAME$PROJECT_WEB" "$PROJECT_NAME$PROJECT_MYSQL" "$PROJECT_NAME$PROJECT_STORAGE" "$PROJECT_NAME$PROJECT_SATIS" "$PROJECT_NAME$PROJECT_MAIL"; docker rmi -f "$PROJECT_NAME$PROJECT_MAIN_I" "$PROJECT_NAME$PROJECT_WEB_I" "$PROJECT_NAME$PROJECT_MYSQL_I" "$PROJECT_NAME$PROJECT_STORAGE_I" "$PROJECT_NAME$PROJECT_SATIS_I" "$PROJECT_NAME$PROJECT_MAIL_I"`) &> /dev/null & spinner $!
    fi
    printf "\n"

  else
    echo "dino.sh | exit"
    exit
  fi

elif [[ "$1" == "reload" || "$1" == "-r" ]]; then
  printf "\n"
  echo "dino.sh | Reload:"
  printf "dino.sh | Reload container and images? [y] "
  read SAY_OK
  if [[ "$SAY_OK" == "y" ]]; then

    printf "\n"
    if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
      docker rm -f "$PROJECT_NAME$PROJECT_MAIN" "$PROJECT_NAME$PROJECT_WEB" "$PROJECT_NAME$PROJECT_MYSQL" "$PROJECT_NAME$PROJECT_STORAGE" "$PROJECT_NAME$PROJECT_SATIS" "$PROJECT_NAME$PROJECT_MAIL"; docker rmi -f "$PROJECT_NAME$PROJECT_MAIN_I" "$PROJECT_NAME$PROJECT_WEB_I" "$PROJECT_NAME$PROJECT_MYSQL_I" "$PROJECT_NAME$PROJECT_STORAGE_I" "$PROJECT_NAME$PROJECT_SATIS_I" "$PROJECT_NAME$PROJECT_MAIL_I"
    else
      (OUTPUT=`rm -rf docker*; docker rm -f "$PROJECT_NAME$PROJECT_MAIN" "$PROJECT_NAME$PROJECT_WEB" "$PROJECT_NAME$PROJECT_MYSQL" "$PROJECT_NAME$PROJECT_STORAGE" "$PROJECT_NAME$PROJECT_SATIS" "$PROJECT_NAME$PROJECT_MAIL"; docker rmi -f "$PROJECT_NAME$PROJECT_MAIN_I" "$PROJECT_NAME$PROJECT_WEB_I" "$PROJECT_NAME$PROJECT_MYSQL_I" "$PROJECT_NAME$PROJECT_STORAGE_I" "$PROJECT_NAME$PROJECT_SATIS_I" "$PROJECT_NAME$PROJECT_MAIL_I"`) &> /dev/null & spinner $!
    fi
    printf "\n"

  else
    echo "dino.sh | exit"
    exit
  fi
fi

if [[ "$1" == "selfupdate" || "$1" == "-u" ]]; then
  echo "dino.sh | Self-Update:"
  printf "dino.sh | Update to the latest dino.sh Version? [y] "
  read SAY_OK
  if [[ "$SAY_OK" == "y" ]]; then

    if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
      wget --no-cache --output-document="dino.sh" https://raw.githubusercontent.com/sbruggmann/dino.sh/master/dino.sh;
    else
      (OUTPUT=`wget --no-cache --output-document="dino.sh" https://raw.githubusercontent.com/sbruggmann/dino.sh/master/dino.sh;`) &> /dev/null & spinner $!
    fi
    NEW_VERSION=$(echo `./dino.sh version tight`)

    echo  "dino.sh | old $CURRENT_VERSION"
    echo "dino.sh | new $NEW_VERSION"
    printf "\n"
    chmod +x dino.sh;
  else
    echo "dino.sh | exit"
  fi
  exit
fi

if [[ "$1" == "links" ]]; then
  echo "dino.sh | Links:"
  echo "dino.sh | Show all symlinks between host-www and www in vm."

  docker exec -it -u www-data "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh links
  exit
fi
if [[ "$1" == "link" ]]; then
  echo "dino.sh | Link:"
  echo "dino.sh | Create a symlink for '$2'"

  # remove slash
  target=${2%/}

  docker exec -it -u www-data "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link $target
  exit
fi
if [[ "$1" == "unlink" ]]; then
  echo "dino.sh | Unlink:"
  echo  "dino.sh | Remove the symlink '$2'"

  # remove slash
  target=${2%/}

  docker exec -it -u www-data "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh unlink $target
  exit
fi

if [[ "$1" == "copy" ]]; then
  echo "dino.sh | Copy:"
  echo "dino.sh | Copy file or folder '$2'"

  # remove slash
  target=${2%/}

  echo "docker exec -it -u www-data "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh copy $target"
  docker exec -it -u www-data "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh copy $target
  echo "dino.sh | done"
  exit
fi

if [[ ( "$1" == "bash" || "$1" == "ssh" ) && ( "$2" == "root" ) ]]; then
  echo "dino.sh | bash:"
  echo "dino.sh | Login as root.."

  docker exec -it -u root "$PROJECT_NAME$PROJECT_MAIN" bash
  printf "\n        | Welcome back on your host terminal\n"
  exit
elif [[ "$1" == "bash" || "$1" == "ssh" ]]; then
  echo "dino.sh | bash:"
  echo "dino.sh | Login as www-data.."

  docker exec -it -u www-data "$PROJECT_NAME$PROJECT_MAIN" bash
  printf "\n        | Welcome back on your host terminal\n"
  exit
fi

if [[ ( "$1" == "satis" ) && ( "$2" == "bash" ) ]]; then
  echo "dino.sh | satis:"
  echo "dino.sh | Login as root.."

  docker-compose run --rm satis bash
  printf "\n        | Welcome back on your host terminal\n"
  exit
fi
if [[ ( "$1" == "satis" ) && ( "$2" == "build" ) ]]; then
  echo "dino.sh | satis:"
  echo "dino.sh | Rebuild.."

  docker-compose run --rm satis bash -c "./scripts/startup.sh && ./scripts/build.sh"
  exit
fi
if [[ ( "$1" == "satis" ) ]]; then
  printf "dino.sh | satis:\n"
  printf "        | Visit http://%s:3080/\n" $DOCKER_IP
  printf "        | Edit  ~/.dino-composer-satis/config/config.json\n"
  printf "\n"
  exit
fi


# startup dino.sh

echo "dino.sh | load.."

if [ ! $GITHUB_TOKEN ]; then
  echo "dino.sh | Github-Check:"
  printf "dino.sh | Add your GitHub OAuth token (github.com > Settings > Personal access tokens): "
  read GITHUB_TOKEN

  echo "dino.sh | Write GitHub OAuth token to .bash_profile"
  echo "export GITHUB_TOKEN=\"$GITHUB_TOKEN\"" >> ~/.bash_profile
fi

if [ ! -d ./docker/ ]; then

  echo "dino.sh | Startup:"
  echo "dino.sh | Create temp folder.."

  mkdir _php-docker-boilerplate
  cd _php-docker-boilerplate

  echo "dino.sh | Clone docker php-boilerplate.."

  if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
    git clone https://github.com/webdevops/php-docker-boilerplate.git .
    git checkout tags/4.0.0
  else
    (OUTPUT=`git clone https://github.com/webdevops/php-docker-boilerplate.git .`) &> /dev/null & spinner $!
    (OUTPUT=`git checkout tags/4.0.0`) &> /dev/null & spinner $!
  fi

  echo "dino.sh | Fetch dino.sh patch.."

  if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
    wget "$PATCH_VERSION_URL"
  else
    (OUTPUT=`wget "$PATCH_VERSION_URL"`) &> /dev/null & spinner $!
  fi

  echo  "dino.sh | Apply patch.. ;)"

  if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
    patch -p1 < patch.diff; rm -rf docker-env.yml
  else
    (OUTPUT=`patch -p1 < patch.diff; rm -rf docker-env.yml`) &> /dev/null & spinner $!
  fi

  cd ..

  echo "dino.sh | Copy files.."


  cp -r _php-docker-boilerplate/docker* ./
  rm -rf _php-docker-boilerplate

fi

# Check dino docker patch version:
if [ -f ./docker/bin/run.sh ]; then
  chmod +x ./docker/bin/run.sh
  DINO_RUN_VERSION=$(echo `./docker/bin/run.sh version tight`)
  if [[ "$CURRENT_VERSION" != "$DINO_RUN_VERSION" ]]; then
    echo "dino.sh | docker Patch is not up to date! ($DINO_RUN_VERSION vs. $CURRENT_VERSION)"
    echo "        | Please update: ./dino.sh reload --force"
    exit
  fi
fi

if [[ "$DINO_SETTINGS_SATIS" == "enabled" ]]; then
  echo  "dino.sh | Enable satis container.."
  sed 's/#satis-disabled //g' docker-compose.yml > docker-compose.yml.tmp && mv docker-compose.yml.tmp docker-compose.yml

  if [ ! -d ~/.dino-composer-satis/cache ]; then
    mkdir -p ~/.dino-composer-satis/cache
  fi
  if [ ! -d ~/.dino-composer-satis/web ]; then
    mkdir -p ~/.dino-composer-satis/web
  fi
  if [ ! -f ~/.dino-composer-satis/config/config.json ]; then
    if [ ! -d ~/.dino-composer-satis/config ]; then
      mkdir -p ~/.dino-composer-satis/config
    fi
    cp "$BASE_PATH/docker/satis/config/config.json" ~/.dino-composer-satis/config/
    echo  "dino.sh | Created a default satis config .."
    echo  "dino.sh | - Edit it at ~/.dino-composer-satis/config/config.json !"
  fi

else
  echo  "dino.sh | Ignore satis container.."
fi

if [[ "$DINO_SETTINGS_MAIL" == "enabled" ]]; then
  echo  "dino.sh | Enable mail catcher.."
  sed 's/#mail-disabled //g' docker-compose.yml > docker-compose.yml.tmp && mv docker-compose.yml.tmp docker-compose.yml
fi

echo "dino.sh | Write GitHub Token: $GITHUB_TOKEN"
echo "$GITHUB_TOKEN" > docker/bin/.github_token
if [ -f ~/.ssh/id_rsa ]; then
  echo "dino.sh | Copy SSH Key.."
  cp ~/.ssh/id_rsa ./docker/etc/ssh/
fi

echo "dino.sh | Stop all docker containers.."

printf "\n"
if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
  docker stop $(docker ps -a -q)
else
  (OUTPUT=`docker stop $(docker ps -a -q)`) &> /dev/null & spinner $!
fi
printf "\n"

echo "dino.sh | Setup $PROJECT_NAME $PROJECT_TYPE.."

if [[ "$PROJECT_TYPE" == "Neos" ]]; then

  echo "dino.sh | Check Neos composer.."

  if [ ! -f ./www/Neos/composer.json ]; then
    if [ ! -d ./www/Neos ]; then
      echo "dino.sh | - Neos Folder created"
      mkdir -p ./www/Neos
    fi
    cd ./www/Neos/
    if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
      wget --no-cache -q https://raw.githubusercontent.com/neos/neos-base-distribution/2.1/composer.json
    else
      (OUTPUT=`wget --no-cache -q https://raw.githubusercontent.com/neos/neos-base-distribution/2.1/composer.json`) &> /dev/null & spinner $!
    fi
    cd ../../
    echo "dino.sh | Neos 2.1 composer.json added"
  fi

fi

if [[ "$PROJECT_TYPE" == "Flow" ]]; then

  echo "dino.sh | Check Flow composer.."

  if [ ! -f ./www/Flow/composer.json ]; then
    if [ ! -d ./www/Flow ]; then
      echo "dino.sh | - Flow folder created"
      mkdir -p ./www/Flow
    fi
    cd ./www/Flow/
    if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
      wget --no-cache -q https://raw.githubusercontent.com/neos/flow-base-distribution/3.1/composer.json
    else
      (OUTPUT=`wget --no-cache -q https://raw.githubusercontent.com/neos/flow-base-distribution/3.1/composer.json`) &> /dev/null & spinner $!
    fi
    cd ../../
    echo "dino.sh | Flow 3.1 composer.json added"
  fi

fi

echo "dino.sh | Load docker $PROJECT_NAME containers.."

if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
  docker-compose up -d
else
  (OUTPUT=`docker-compose up -d`) &> /dev/null & spinner $!
fi
printf "\n"

echo "dino.sh | Wait until ready.."
if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
  dockerReady "$DOCKER_IP"
else
  if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
    dockerReady "$DOCKER_IP"
  else
    (OUTPUT=`dockerReady "$DOCKER_IP"`) &> /dev/null & spinner $!
  fi
fi

echo "dino.sh | Setup $PROJECT_NAME $PROJECT_TYPE.."

docker exec -it "$PROJECT_NAME$PROJECT_MAIN" chmod +x /docker/bin/run.sh

if [[ "$PROJECT_TYPE" == "Neos" ]]; then

  echo "dino.sh | Check Neos Folders."
  if [ ! -d ./www/Neos/Build/Surf ]; then
    echo "dino.sh | - Build/Surf created"
    mkdir -p ./www/Neos/Build/Surf
  fi

  if [ ! -d ./www/Neos/Configuration/Development ]; then
    echo "dino.sh | - Configuration/Development created"
    mkdir -p ./www/Neos/Configuration/Development
  fi
  if [ ! -d ./www/Neos/Configuration/Production/Local ]; then
    echo "dino.sh | - Configuration/Production/Local created"
    mkdir -p ./www/Neos/Configuration/Production/Local
  fi

  if [ ! -d ./www/Neos/Packages/Plugins ]; then
    echo "dino.sh | - Packages/Plugins created"
    mkdir -p ./www/Neos/Packages/Plugins
  fi

  if [ ! -d ./www/Neos/Packages/Sites ]; then
    echo "dino.sh | - Packages/Sites created"
    mkdir -p ./www/Neos/Packages/Sites
  fi

  if [ ! -d ./www/Neos/Web ]; then
    echo "dino.sh | - Web created"
    mkdir -p ./www/Neos/Web
  fi

  if [ ! -f ./www/Neos/composer.json ]; then
    cd ./www/Neos/
    if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
      wget --no-cache -q https://raw.githubusercontent.com/neos/neos-base-distribution/2.1/composer.json
    else
      (OUTPUT=`wget --no-cache -q https://raw.githubusercontent.com/neos/neos-base-distribution/2.1/composer.json`) &> /dev/null & spinner $!
    fi
    cd ../../
    echo "dino.sh | Added Neos 2.1 composer.json"
  fi

  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh create folder www/Neos/Build
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh create folder www/Neos/Packages
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh create folder www/Neos/Web

  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh remove folder www/public
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" ln -s /docker/www/Neos/Web /docker/www/public

  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Neos/Build/Surf h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Neos/Configuration h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Neos/Packages/Plugins h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Neos/Packages/Sites h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Neos/Web/.htaccess h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Neos/Web/robots.txt h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Neos/composer.json h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Neos/composer.lock h

fi

if [[ "$PROJECT_TYPE" == "Flow" ]]; then

  echo "dino.sh | Check Flow Folders."
  if [ ! -d ./www/Flow/Build/Surf ]; then
    echo "dino.sh | - Build/Surf created"
    mkdir -p ./www/Flow/Build/Surf
  fi

  if [ ! -d ./www/Flow/Configuration/Development ]; then
    echo "dino.sh | - Configuration/Development created"
    mkdir -p ./www/Flow/Configuration/Development
  fi
  if [ ! -d ./www/Flow/Configuration/Production/Local ]; then
    echo "dino.sh | - Configuration/Production/Local created"
    mkdir -p ./www/Flow/Configuration/Production/Local
  fi

  if [ ! -d ./www/Flow/Packages/Application ]; then
    echo "dino.sh | - Packages/Application created"
    mkdir -p ./www/Flow/Packages/Application
  fi

  if [ ! -d ./www/Flow/Web ]; then
    echo "dino.sh | - Web created"
    mkdir -p ./www/Flow/Web
  fi

  if [ ! -f ./www/Flow/composer.json ]; then
    cd ./www/Flow/
    if [[ "$DINO_SETTINGS_OUTPUT" == "verbose" ]]; then
      wget --no-cache -q https://raw.githubusercontent.com/neos/flow-base-distribution/3.1/composer.json
    else
      (OUTPUT=`wget --no-cache -q https://raw.githubusercontent.com/neos/flow-base-distribution/3.1/composer.json`) &> /dev/null & spinner $!
    fi
    cd ../../
    echo "dino.sh | Added Flow 3.1 composer.json"
  fi

  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh create folder www/Flow/Build
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh create folder www/Flow/Packages
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh create folder www/Flow/Web

  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh remove folder www/public
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" ln -s /docker/www/Flow/Web /docker/www/public

  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Flow/Build/Surf h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Flow/Configuration h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Flow/Packages/Application h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Flow/Web/.htaccess h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Flow/Web/robots.txt h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Flow/composer.json h
  docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh link www/Flow/composer.lock h

fi


echo "dino.sh | Check Development Settings.."

if grep -q "dbname: db" "./www/$PROJECT_TYPE/Configuration/Development/Settings.yaml"; then
  echo "| Configuration/Settings.yaml exists"
else
  echo "TYPO3:" > "./www/$PROJECT_TYPE/Configuration/Settings.yaml"
  echo "  Flow:" >> "./www/$PROJECT_TYPE/Configuration/Settings.yaml"
  echo "    persistence:" >> "./www/$PROJECT_TYPE/Configuration/Settings.yaml"
  echo "      backendOptions:" >> "./www/$PROJECT_TYPE/Configuration/Settings.yaml"
  echo "        driver: pdo_mysql" >> "./www/$PROJECT_TYPE/Configuration/Settings.yaml"
  echo "        dbname: db" >> "./www/$PROJECT_TYPE/Configuration/Settings.yaml"
  echo "        user: user" >> "./www/$PROJECT_TYPE/Configuration/Settings.yaml"
  echo "        password: pass" >> "./www/$PROJECT_TYPE/Configuration/Settings.yaml"
  echo "        host: mysql" >> "./www/$PROJECT_TYPE/Configuration/Settings.yaml"
  echo "| wrote Configuration/Settings.yaml"
fi
if [ ! -d "./www/$PROJECT_TYPE/Configuration/Production/Local" ]; then
  mkdir -p "./www/$PROJECT_TYPE/Configuration/Production/Local"
fi
if [ ! -f "./www/$PROJECT_TYPE/Configuration/Production/Local/Settings.yaml" ]; then
  echo "TYPO3:" > "./www/$PROJECT_TYPE/Configuration/Production/Local/Settings.yaml"
  echo "  Flow:" >> "./www/$PROJECT_TYPE/Configuration/Production/Local/Settings.yaml"
  echo "    persistence:" >> "./www/$PROJECT_TYPE/Configuration/Production/Local/Settings.yaml"
  echo "      backendOptions:" >> "./www/$PROJECT_TYPE/Configuration/Production/Local/Settings.yaml"
  echo "        driver: pdo_mysql" >> "./www/$PROJECT_TYPE/Configuration/Production/Local/Settings.yaml"
  echo "        dbname: db" >> "./www/$PROJECT_TYPE/Configuration/Production/Local/Settings.yaml"
  echo "        user: user" >> "./www/$PROJECT_TYPE/Configuration/Production/Local/Settings.yaml"
  echo "        password: pass" >> "./www/$PROJECT_TYPE/Configuration/Production/Local/Settings.yaml"
  echo "        host: mysql" >> "./www/$PROJECT_TYPE/Configuration/Production/Local/Settings.yaml"
  echo "| wrote Configuration/Production/Local/Settings.yaml"
fi


TIME_BEFORE_NEOS=$(date +%s)

printf "\n"

if [[ "$DINO_SETTINGS_SATIS" == "enabled" ]]; then
  if [ ! -f ~/.dino-composer-satis/web/index.html ]; then
    docker-compose run --rm satis bash -c "./scripts/startup.sh && ./scripts/build.sh"
  else
    docker-compose run --rm satis bash -c "./scripts/startup.sh"
  fi
fi

docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh install "$PROJECT_TYPE"
#(OUTPUT=`docker exec -it "$PROJECT_NAME$PROJECT_MAIN" /docker/bin/run.sh install "$PROJECT_TYPE"`) &> /dev/null & spinner $!

if grep -q "# dino.sh context configuration:" "./www/$PROJECT_TYPE/Web/.htaccess"; then
  echo "dino.sh | Check .htaccess FLOW_CONTEXT"
else
  echo "dino.sh | Write .htaccess FLOW_CONTEXT"
  echo "\n# dino.sh context configuration:" >> "./www/$PROJECT_TYPE/Web/.htaccess"
  echo "SetEnvIf Host \.dev$ FLOW_CONTEXT=Development" >> "./www/$PROJECT_TYPE/Web/.htaccess"
  echo "SetEnvIf Host \.prod$ FLOW_CONTEXT=Production/Local" >> "./www/$PROJECT_TYPE/Web/.htaccess"
  echo "SetEnvIf Host ^stage\. FLOW_CONTEXT=Production/Stage" >> "./www/$PROJECT_TYPE/Web/.htaccess"
  echo "RewriteCond %{HTTP_HOST} !\.dev$" >> "./www/$PROJECT_TYPE/Web/.htaccess"
  echo "RewriteCond %{HTTP_HOST} !\.prod$" >> "./www/$PROJECT_TYPE/Web/.htaccess"
  echo "RewriteCond %{HTTP_HOST} !^stage" >> "./www/$PROJECT_TYPE/Web/.htaccess"
  echo "RewriteRule (.*) $1 [E=FLOW_CONTEXT:Production]" >> "./www/$PROJECT_TYPE/Web/.htaccess"
fi

printf "\n"

DOMAIN_NAME=$(echo ${PWD##*/} | sed 's/\..*//g')

if [ ! -f ./npm-shrinkwrap.json ]; then
  echo "dino.sh | PLEASE add a npm-shrinkwrap.json File!"
  printf "dino.sh | "
  npm shrinkwrap -dev
fi

if [ ! -f ./.nvmrc ]; then
  echo "dino.sh | PLEASE add a .nvmrc File!"
  node -v > .nvmrc
  echo "dino.sh | wrote .nvmrc"
fi

if [ ! -f ~/.ssh/id_rsa ]; then
  echo "dino.sh | PLEASE create an SSH Key for Bitbucket!"
  echo "dino.sh | see: https://confluence.atlassian.com/bitbucket/set-up-ssh-for-mercurial-728138122.html"
  echo "dino.sh | restart dino.sh"
fi

TIME_AFTER=$(date +%s)

printf "dino.sh | READY after %s seconds (%s seconds for Docker / %s seconds for $PROJECT_TYPE)\n" $(($TIME_AFTER - $TIME_BEFORE)) $(($TIME_BEFORE_NEOS - $TIME_BEFORE)) $(($TIME_AFTER - $TIME_BEFORE_NEOS))
echo "        | #####"
printf "\n\n"

echo "dino.sh |    Started Docker:       docker-compose up -d"
printf "        | 1. Connect Container:    ./dino.sh ssh            docker exec -it -u www-data %s_main_1 bash\n" $PROJECT_NAME
printf "        |                          ./dino.sh ssh root       docker exec -it -u root %s_main_1 bash\n" $PROJECT_NAME
printf "        | 2. Add to /etc/hosts:    %s %s.dev www.%s.dev %s.prod www.%s.prod\n" $DOCKER_IP $DOMAIN_NAME $DOMAIN_NAME $DOMAIN_NAME $DOMAIN_NAME
printf "        | 3. Open Site:            http://%s.dev\n" $DOMAIN_NAME
printf "        |                          http://%s.prod\n" $DOMAIN_NAME
if [[ "$DINO_SETTINGS_SATIS" == "enabled" ]]; then
  printf "        | 4. Show Satis Packages:  http://%s:3080/\n" $DOCKER_IP
  printf "        |                          Edit ~/.dino-composer-satis/config/config.json\n"
fi
echo "        |    Stop Docker:          docker-compose stop"
printf "\n\n\n"