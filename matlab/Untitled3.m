% Define file paths for your CSV data
sensorDataFile = 'sensor_data.csv',1,0; % Update with your actual CSV file
expectedDataFile = 'open_source_data.csv',1,0; % Update with your actual CSV file

% Define grid parameters
gridSize = 0.005;  % Grid cell size in degrees (adjust according to your study area)


% Filter sensor data to include only points within the grid boundaries
validIndices = (sensorData(:, 1) >= latitudeRange(1) & sensorData(:, 1) <= latitudeRange(2)) & ...
               (sensorData(:, 2) >= longitudeRange(1) & sensorData(:, 2) <= longitudeRange(2));
filteredSensorData = sensorData(validIndices, :);

% Call the function with the filtered sensor data
detectAndAnalyzeAnomalies(filteredSensorData, expectedDataFile, gridSize, threshold);


% Define anomaly detection threshold (adjust as needed)
threshold = 0.05;  % Adjust the threshold

% Call the function to detect anomalies and analyze results
detectAndAnalyzeAnomalies(sensorDataFile, expectedDataFile, gridSize, threshold);

function detectAndAnalyzeAnomalies(sensorDataFile, expectedDataFile, gridSize, threshold)
    % Import sensor-detected data from CSV
    sensorData = csvread(sensorDataFile, 1, 0); % Skip the header row

    % Import open-source data from CSV (This is your expected magnetic field data)
    expectedData = csvread(expectedDataFile, 1, 0); % Skip the header row

    % Define grid parameters and create a grid
    latitudeRange = [min(sensorData(:, 1)) max(sensorData(:, 1))];
    longitudeRange = [min(sensorData(:, 2)) max(sensorData(:, 2))];
    [gridLatitude, gridLongitude] = meshgrid(latitudeRange(1):gridSize:latitudeRange(2), ...
                                             longitudeRange(1):gridSize:longitudeRange(2));

    % Initialize arrays to store expected and measured magnetic field values
    expectedField = zeros(size(gridLatitude));

    % Clip latitude and longitude values to be within the grid range
    clippedLatitude = min(max(sensorData(:, 1), latitudeRange(1)), latitudeRange(2));
    clippedLongitude = min(max(sensorData(:, 2), longitudeRange(1)), longitudeRange(2));

    % Calculate expected magnetic field values for each grid cell using expected data
    for i = 1:numel(gridLatitude)
        latitude = gridLatitude(i);
        longitude = gridLongitude(i);

        % Find the corresponding value in your expected data (assuming latitude and longitude match)
        expectedField(i) = findExpectedField(latitude, longitude, expectedData);
    end

    % Calculate the deviation
    rowIndices = round((clippedLatitude - latitudeRange(1)) / gridSize) + 1;
    colIndices = round((clippedLongitude - longitudeRange(1)) / gridSize) + 1;

    deviation = abs(sensorData(:, 3) - expectedField(sub2ind(size(gridLatitude), rowIndices, colIndices)));

    % Detect anomalies based on deviation and threshold
    anomalies = deviation > threshold;

    % Calculate performance metrics
    true_positives = sum(anomalies);
    false_positives = sum(~anomalies);
    false_negatives = sum(sensorData(:, 3) > expectedField(sub2ind(size(gridLatitude), rowIndices, colIndices)) & ~anomalies);
    precision = true_positives / (true_positives + false_positives);
    recall = true_positives / (true_positives + false_negatives);
    f1_score = 2 * (precision * recall) / (precision + recall);

    % Calculate anomaly intensity and size
    anomaly_intensity = sensorData(anomalies, 3) - expectedField(sub2ind(size(gridLatitude), rowIndices(anomalies), colIndices(anomalies)));
    anomaly_size = gridSize;  % Assuming each grid cell represents a unit area

    % Visualize anomalies with intensity and size (optional)
    figure;
    scatter(sensorData(anomalies, 2), sensorData(anomalies, 1), 'r', 'filled');  % Anomaly points in red
    hold on;
    scatter(sensorData(~anomalies, 2), sensorData(~anomalies, 1), 'b');  % Measured data points in blue
    xlabel('Longitude');
    ylabel('Latitude');
    title('Gridded Magnetic Anomaly Detection');
    legend('Detected Anomalies', 'Measured Data');

    % Display results, including the number of detected anomalies, metrics, intensity, and size
    fprintf('Number of Detected Anomalies: %d\n', true_positives);
    fprintf('Precision: %.2f\n', precision);
    fprintf('Recall: %.2f\n', recall);
    fprintf('F1 Score: %.2f\n', f1_score);
    fprintf('Anomaly Intensity: %.2f\n', mean(anomaly_intensity));
    fprintf('Anomaly Size: %.2f square degrees\n', mean(anomaly_size));
end

function expectedValue = findExpectedField(latitude, longitude, expectedData)
    % Find the row index corresponding to the provided latitude and longitude
    % In your expectedData, the first two columns should contain latitude and longitude
    latitudes = expectedData(:, 1);
    longitudes = expectedData(:, 2);

    % Search for the index where latitude and longitude match
    matchingIndex = find(latitudes == latitude & longitudes == longitude);

    if ~isempty(matchingIndex)
        % If a match is found, return the corresponding expected value
        expectedValue = expectedData(matchingIndex, 3); % Assuming the expected value is in the third column
    else
        % If no match is found, you can handle it as needed (e.g., return a default value)
        expectedValue = NaN; % Return NaN for unmatched data points
    end
end
