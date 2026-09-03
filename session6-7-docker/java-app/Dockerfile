# -------------------------
# Stage 1: Compile the Java source
# -------------------------
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /build

COPY HelloWorld.java .

RUN javac HelloWorld.java

# -------------------------
# Stage 2: Run on a smaller JRE image
# -------------------------
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

COPY --from=builder /build/HelloWorld.class .

EXPOSE 8080

CMD ["java", "HelloWorld"]
