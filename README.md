## docker-logstash : Docker image with logstash 1.5.X + TCP/TLS gelf support

Simplified fork of edefaria's [docker-logstash](https://github.com/edefaria/docker-logstash) image.

The primary concern of this docker image is to support GELF with TCP. Also added experimental support for inserting environment vars into the logstash configuration file.

### Build

```
$ git clone https://github.com/adrianlyjak/docker-logstash.git
$ cd docker-logstash
$ docker build -t logstash-gelf-tcp .
```

### Run

either set the `LOGSTASH_CONF` environment variable

```
docker run -i -e 'LOGSTASH_CONF="input{stdin{}} output{stdout{}}"' logstash-gelf-tcp
```
or attach a folder to `/opt/logs` (better to be read-only) and add a `logstash.conf` file

```
docker run -d -v ~/logstash-input:/opt/logs:ro logstash-gelf-tcp
```

### Usage

`logstash.conf` supports environment variables


```
docker run -i -v ~/logstash-input:/opt/logs:ro logstash-gelf-tcp -e "OUTPUT_TCP_PORT=9999"
```

```
input {
	stdin {}
}

output {
	stdout {
		host => "awesomeserver.com"
		port => "$OUTPUT_TCP_PORT"
	}
}

```
Gelf output takes extra optional parameters `protocol` and `tls`

```
output {
  gelf {
    host => "localhost"
    port => 12202
    protocol => "tcp"
    tls => "true"
  }
  stdout {}
}
```
