REGISTRY?=kong-docker-kubernetes-ingress-controller.bintray.io
REDHAT_REGISTRY?=scan.connect.redhat.com/ospid-f8304390-ff4c-4b7f-8c7e-1ed13370b3c2
TAG?=1.1.1
REPO_INFO=$(shell git config --get remote.origin.url)
IMGNAME?=kong-ingress-controller
IMAGE = $(REGISTRY)/$(IMGNAME)
REDHAT_IMAGE = $(REDHAT_REGISTRY)/$(IMGNAME)
# only for dev
DB?=false
RUN_VERSION?=20
KUBE_VERSION?=v1.20.2

ifndef COMMIT
  COMMIT := $(shell git rev-parse --short HEAD)
endif

export GO111MODULE=on

.PHONY: test-all
test-all: lint test

.PHONY: test
test:
	go test -race ./...

.PHONY: coverage
coverage:
	go test -race -v -count=1 -coverprofile=coverage.out.tmp ./...
	# ignoring generated code for coverage
	grep -E -v 'pkg/apis/|pkg/client/|generated.go|generated.deepcopy.go' coverage.out.tmp > coverage.out
	rm -f coverage.out.tmp

.PHONY: lint
lint: verify-tidy
	golangci-lint run ./...

.PHONY: build
build:
	CGO_ENABLED=0 go build -o kong-ingress-controller ./cli/ingress-controller

.PHONY: verify-manifests
verify-manifests:
	./hack/verify-manifests.sh

.PHONY: verify-codegen
verify-codegen:
	./hack/verify-codegen.sh

.PHONY: update-codegen
update-codegen:
	./hack/update-codegen.sh

.PHONY: verify-tidy
verify-tidy:
	./hack/verify-tidy.sh

.PHONY: container
container:
	docker build \
    --build-arg TAG=${TAG} --build-arg COMMIT=${COMMIT} \
    --build-arg REPO_INFO=${REPO_INFO} \
    -t ${IMAGE}:${TAG} .

.PHONY: redhat-container
redhat-container:
	docker build \
    --build-arg TAG=${TAG} --build-arg COMMIT=${COMMIT} \
    --build-arg REPO_INFO=${REPO_INFO} \
	-f RedHatDockerfile \
    -t ${REDHAT_IMAGE}:${TAG} .

.PHONY: run
run:
	./hack/dev/start.sh ${DB} ${RUN_VERSION}


.PHONY: integration-test
integration-test: container
	KIC_IMAGE="${IMAGE}:${TAG}" KUBE_VERSION=${KUBE_VERSION} ./test/integration/test.sh
