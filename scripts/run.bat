@echo off
REM Windows batch script for Arduino Sensor Data Processor Docker containers
REM This provides basic Docker management functionality for Windows users

setlocal enabledelayedexpansion

REM Configuration
set IMAGE_NAME=arduino-sensor-processor
set CONTAINER_NAME=arduino-sensor-processor
set DEFAULT_PORT=5000
set DEFAULT_SERIAL_PORT=COM3

REM Colors (if supported)
set GREEN=[92m
set YELLOW=[93m
set RED=[91m
set NC=[0m

:main
if "%1"=="" goto usage
if "%1"=="start" goto start
if "%1"=="stop" goto stop
if "%1"=="restart" goto restart
if "%1"=="logs" goto logs
if "%1"=="shell" goto shell
if "%1"=="status" goto status
if "%1"=="cleanup" goto cleanup
if "%1"=="help" goto usage
if "%1"=="-h" goto usage
if "%1"=="--help" goto usage

echo %RED%Unknown command: %1%NC%
goto usage

:usage
echo Usage: %0 COMMAND [OPTIONS]
echo.
echo Commands:
echo   start        Start the container
echo   stop         Stop the container
echo   restart      Restart the container
echo   logs         Show container logs
echo   shell        Open shell in running container
echo   status       Show container status
echo   cleanup      Remove stopped containers and unused images
echo   help         Show this help message
echo.
echo Examples:
echo   %0 start                          # Start production container
echo   %0 logs                           # Show container logs
echo   %0 shell                          # Open shell in running container
echo   %0 stop                           # Stop container
echo.
echo Note: For advanced options, use Docker Compose:
echo   docker-compose up -d              # Start with docker-compose
echo   docker-compose -f docker-compose.dev.yml up -d  # Start development
goto end

:start
echo %GREEN%Starting Arduino Sensor Data Processor container...%NC%

REM Check if container is already running
docker ps --format "{{.Names}}" | findstr /C:"%CONTAINER_NAME%" >nul
if !errorlevel! equ 0 (
    echo %GREEN%Container is already running%NC%
    goto end
)

REM Remove existing stopped container
docker ps -a --format "{{.Names}}" | findstr /C:"%CONTAINER_NAME%" >nul
if !errorlevel! equ 0 (
    echo Removing existing stopped container...
    docker rm %CONTAINER_NAME% >nul 2>&1
)

REM Check if .env file exists
if not exist ".env" (
    echo %YELLOW%Warning: .env file not found%NC%
    echo Create a .env file with your configuration
)

REM Start container with basic configuration
echo Starting container with image: %IMAGE_NAME%:latest
docker run -d ^
    --name %CONTAINER_NAME% ^
    --restart unless-stopped ^
    -p %DEFAULT_PORT%:5000 ^
    --env-file .env ^
    -v "%cd%\logs:/app/logs" ^
    %IMAGE_NAME%:latest

if !errorlevel! equ 0 (
    echo %GREEN%Container started successfully%NC%
    echo Access the application at: http://localhost:%DEFAULT_PORT%
    echo Check status with: %0 status
    echo View logs with: %0 logs
) else (
    echo %RED%Failed to start container%NC%
)
goto end

:stop
echo %GREEN%Stopping container...%NC%
docker ps --format "{{.Names}}" | findstr /C:"%CONTAINER_NAME%" >nul
if !errorlevel! neq 0 (
    echo Container is not running
    goto end
)

docker stop %CONTAINER_NAME% >nul
if !errorlevel! equ 0 (
    echo %GREEN%Container stopped successfully%NC%
) else (
    echo %RED%Failed to stop container%NC%
)
goto end

:restart
echo %GREEN%Restarting container...%NC%
call :stop
timeout /t 2 /nobreak >nul
call :start
goto end

:logs
echo %GREEN%Showing container logs...%NC%
docker ps -a --format "{{.Names}}" | findstr /C:"%CONTAINER_NAME%" >nul
if !errorlevel! neq 0 (
    echo %RED%Container does not exist%NC%
    goto end
)

docker logs %CONTAINER_NAME%
goto end

:shell
echo %GREEN%Opening shell in container...%NC%
docker ps --format "{{.Names}}" | findstr /C:"%CONTAINER_NAME%" >nul
if !errorlevel! neq 0 (
    echo %RED%Container is not running%NC%
    goto end
)

docker exec -it %CONTAINER_NAME% /bin/bash
goto end

:status
echo %GREEN%Container Status:%NC%
docker ps -a --filter "name=%CONTAINER_NAME%" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

REM Show resource usage if running
docker ps --format "{{.Names}}" | findstr /C:"%CONTAINER_NAME%" >nul
if !errorlevel! equ 0 (
    echo.
    echo Resource Usage:
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" %CONTAINER_NAME%
)
goto end

:cleanup
echo %GREEN%Cleaning up Docker resources...%NC%

REM Stop and remove container if exists
docker ps -a --format "{{.Names}}" | findstr /C:"%CONTAINER_NAME%" >nul
if !errorlevel! equ 0 (
    docker ps --format "{{.Names}}" | findstr /C:"%CONTAINER_NAME%" >nul
    if !errorlevel! equ 0 (
        docker stop %CONTAINER_NAME% >nul 2>&1
    )
    docker rm %CONTAINER_NAME% >nul 2>&1
    echo Removed container: %CONTAINER_NAME%
)

REM Remove dangling images
docker image prune -f >nul 2>&1

REM Remove unused volumes
docker volume prune -f >nul 2>&1

echo %GREEN%Cleanup completed%NC%
goto end

:end
endlocal