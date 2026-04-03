FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY Bugay.Api.Example.csproj ./Bugay.Api.Example/
RUN dotnet restore ./Bugay.Api.Example/Bugay.Api.Example.csproj

COPY . ./Bugay.Api.Example/
RUN dotnet publish ./Bugay.Api.Example/Bugay.Api.Example.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Bugay.Api.Example.dll"]
