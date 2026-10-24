function frame = analog_sample_to_marker_frame(sampleIdx, fsAnalog, fsMarker)
    frame = round((double(sampleIdx) - 1) / double(fsAnalog) * double(fsMarker)) + 1;
    frame = max(1, frame);
end
