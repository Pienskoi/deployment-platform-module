FROM azul/zulu-openjdk-debian:17-latest as build
WORKDIR /app

COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
COPY src src

RUN ./mvnw install -DskipTests

FROM azul/zulu-openjdk-debian:17-jre-latest
RUN useradd -r spring
USER spring:spring

COPY --from=build /app/target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]