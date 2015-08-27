#!/bin/bash

#Author: Edward De Faria <edward.de-faria@ovh.net>
if [ -z "$LOGSTASH_HOME" ] ; then
  export LOGSTASH_HOME=/opt/logstash
fi
export GEM_HOME=vendor/bundle/jruby/1.9
export GEM_PATH=$GEN_HOME
export USE_JRUBY=1

GIT_PULL=1

gem_list () {
  pushd $LOGSTASH_HOME > /dev/null
  if [ -d "vendor/jar" ] ; then
    local vendor_path=$(find vendor/jar -iname jruby-complete*.jar)
    java -jar $vendor_path -S gem list -i $GEM_HOM
  elif [ -d "vendor/jruby" ] ; then
    ./vendor/jruby/bin/jruby -S gem list
  else
    echo "Error: jruby dependancy missing!"
  fi
  popd > /dev/null
}

rake_update () {
  pushd $LOGSTASH_HOME > /dev/null
  if [ -f "Rakefile" ] ; then
    echo "exec in $PWD: rake vendor:gems"
    rake vendor:gems
  else
    echo "logstash package installation found, skipping rake"
  fi
  popd > /dev/null
}

git_check () {
  local home="$1"
  local gem_name="$2"
  local git_clone_params="$3"
  if [ ! -d "$home" ] ; then
    cd $(dirname $home)
    echo "exec in $PWD: git clone $git_clone_params $(basename $home)"
    git clone $git_clone_params "$(basename $home)" || { echo "git clone failed" ; exit 1 ; }
    cd $home
  else
    cd $home
    [ "$GIT_PULL" == "1" ] && { echo "exec in $PWD: git pull origin master" ; git pull origin master  || { echo "git pull failed" ; exit 1 ; } ; }
  fi
}

rubygems_update () {
  if which gem 2>1 >/dev/null ; then
    local gem_cmd="gem"
  else
    echo "command gem not found! Please install ruby/gem package!"
    exit 1
  fi
  local gem_version="$($gem_cmd --version)"
  if [[ "2.0.0" > "$gem_version" ]]; then
    if [[ "1.5.1" < "$gem_version" ]]; then
      REALLY_GEM_UPDATE_SYSTEM=1 $gem_cmd update --system
      if [ "$?" != "0" ] ; then
        $gem_cmd install rubygems-update
        source /etc/profile
        update_rubygems
      fi
    else
      $gem_cmd install rubygems-update
      source /etc/profile
      update_rubygems
    fi
  fi
}

gem_get_version () {
  local gem_name=$1
  #Get first version of gem package asked
  gem_list|grep -w "^$gem_name" |sed -r 's#^.*\((.*)\).*$#\1#'|cut -d ',' -f1
}

gem_version () {
  local home=$1
  local gem_name=$2
  local version=$3
  if [ -z "$version" ] ; then
    local version=$(gem_get_version $gem_name)
  fi
  if [ -z "$version" ] ; then
    if [ -f "$home/VERSION" ] ; then
      local version=$(cat $home/VERSION)
    else
      local $(grep 's\.version' $gem_name.gemspec |tr -d ' ' |sed -e 's/s\.version/version/' -e "s/'//g" -e 's/"//g')
    fi
  else
    [ -f "$home/VERSION" ] && echo $version > $home/VERSION
    sed -i "s/\(s\.version .*= \).*/\1'$version'/g" $gem_name.gemspec >/dev/null 2>/dev/null || { echo "version modification failed on filed $PWD/$gem_name.gemspec" ; exit 1 ; }
  fi
  echo $version
}

gem_build () {
  local home="$1"
  local gem_name="$2"
  local version="$3"
  cd $home
  if which gem 2>1 >/dev/null ; then
    local gem_cmd="gem"
  elif [ -x "/usr/bin/gem" ] ; then
    local gem_cmd="/usr/bin/gem"
  elif [ -x "$LOGSTASH_HOME/vendor/jruby/bin/gem" ] ; then
    local gem_cmd="$LOGSTASH_HOME/vendor/jruby/bin/gem"
    echo "please install gem command"
    exit 1
  else
    echo "command gem not found! Please install gem package!"
    exit 1
  fi
  echo "exec in $PWD: $gem_cmd build $gem_name.gemspec"
  $gem_cmd build $gem_name.gemspec
}

plugin_install () {
  local home="$1"
  local gem_name="$2"
  local git_clone_params="$3"
  local action="$4"
  git_check "$home" "$gem_name" "$git_clone_params"
  local version=$(gem_version "$home" "$gem_name" "$version")
  gem_build "$home" "$gem_name" "$version"
  cd $LOGSTASH_HOME
  [ -z "$action" ] && local action=install
  if [ -x "bin/plugin" ] ; then
    echo "exec in $PWD: ( bin/plugin $action $home/$gem_name-$version.gem )"
    bin/plugin $action $home/$gem_name-$version.gem
  else
    echo "Error: plugin exec missing!"
    exit 1
  fi
}

plugin_update () {
  local home="$1"
  local gem_name="$2"
  local git_clone_params="$3"
  local version="$4"
  local version=$(gem_version "$home" "$gem_name" "$version")
  plugin_install "$home" "$gem_name" "$git_clone_params" "update"
}

plugin_install_noverify () {
  local home="$1"
  local gem_name="$2"
  local git_clone_params="$3"
  local version="$4"
  local version=$(gem_version "$home" "$gem_name" "$version")
  plugin_install "$home" "$gem_name" "$git_clone_params" "install --no-verify"
}

gem_update () {
  local home="$1"
  local gem_name="$2"
  local git_clone_params="$3"
  local version="$4"
  git_check "$home" "$gem_name" "$git_clone_params"
  local version=$(gem_version "$home" "$gem_name" "$version")
  gem_build "$home" "$gem_name" "$version"
  cd $LOGSTASH_HOME
  local action=install
  if [ -d "vendor/jar" ] ; then
    local vendor_path=$(find vendor/jar -iname jruby-complete*.jar)
    echo "exec in $PWD: java -jar $vendor_path -S gem $action -i $GEM_HOME $home/$gem_name-$version.gem"
    java -jar $vendor_path -S gem $action -i $GEM_HOME $home/$gem_name-$version.gem || { echo "gem install failed" ; exit 1 ; }
  elif [ -d "vendor/jruby" ] ; then
    echo "exec in $PWD: ./vendor/jruby/bin/jruby -S gem $action $home/$gem_name-$version.gem"
    ./vendor/jruby/bin/jruby -S gem $action $home/$gem_name-$version.gem || { echo "gem install failed" ; exit 1 ; }
  else
    echo "Error: jruby dependancy missing!"
    exit 1
  fi
}

# Check rubygems version requirement
rubygems_update

# Install gelf-rb patched
gem_update /opt/gelf-rb gelf "-b feature/tcp-tls --single-branch https://github.com/edefaria/gelf-rb.git"

# Install logstash plugin output gelf patched
plugin_install /opt/logstash-output-gelf logstash-output-gelf "-b feature/tcp-tls --single-branch https://github.com/edefaria/logstash-output-gelf.git"

# Install logstash plugin codec gelf
plugin_install /opt/logstash-codec-gelf logstash-codec-gelf "https://github.com/edefaria/logstash-codec-gelf.git"

# Install logstash plugin input gelf patched
plugin_install /opt/logstash-input-gelf logstash-input-gelf "https://github.com/edefaria/logstash-input-gelf.git"

# Update Logstash dependencies
rake_update
