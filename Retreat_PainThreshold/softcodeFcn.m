function softcodeFcn(Byte)
    global BpodSystem

    switch(Byte)
        case 1
            disp('Press button to start.')
        case 2
            disp('Waiting ...')
            beep
        case 3
            disp('Timeout!')
        case 4
            disp('Starting stimulus.')
        case 5
            
        case 6
            disp('Hit!')
        case 7
            disp('End of trial.')
    end
end
